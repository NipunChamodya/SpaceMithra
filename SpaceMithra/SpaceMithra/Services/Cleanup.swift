import Foundation

public protocol TrashOperations: Sendable {
    func trash(_ url: URL) throws -> URL
    func restore(_ source: URL, to destination: URL) throws
}
/// The journal must durably acknowledge each write before mutation can proceed.
/// A small interface allows tests to inject storage failures at transaction boundaries.
public protocol CleanupJournal: Sendable {
    func protections() async throws -> [Protection]
    func history() async throws -> [HistoryEntry]
    func saveHistory(_ entry: HistoryEntry) async throws
}
extension Catalog: CleanupJournal {}
public struct SystemTrash: TrashOperations {
    public init() {}
    public func trash(_ url: URL) throws -> URL {
        var result: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &result)
        guard let result else { throw StorageError.refused("error.trashUncertain") }
        return result as URL
    }
    public func restore(_ source: URL, to destination: URL) throws { try FileManager.default.moveItem(at: source, to: destination) }
}
public actor CleanupEngine {
    private let catalog: any CleanupJournal
    private let operations: any TrashOperations
    private var busy = false
    private var cleaning = false
    private var cancellation: CleanupCancellation?
    public init(catalog: any CleanupJournal, operations: any TrashOperations = SystemTrash()) { self.catalog = catalog; self.operations = operations }
    public func requestCancellation() { if cleaning { cancellation?.cancel() } }
    private var shouldCancel: Bool { (cancellation?.isCancelled ?? false) || Task.isCancelled }
    public func clean(confirmed records: [FileRecord], cancellation: CleanupCancellation = CleanupCancellation(), progress: @Sendable (CleanupProgress) async -> Void = { _ in }) async throws -> [HistoryEntry] {
        guard !busy else { throw StorageError.refused("error.busy") }
        busy = true; cleaning = true; self.cancellation = cancellation
        defer { busy = false; cleaning = false; self.cancellation = nil }
        let session = UUID().uuidString
        var results: [HistoryEntry] = []
        var state = CleanupProgress(total: records.count)
        await progress(state)
        for record in records {
            var entry = HistoryEntry(id: UUID().uuidString, session: session, record: record, date: Date(), status: "pending", message: "message.pending")
            if shouldCancel { entry.status = "cancelled"; entry.message = "message.cancelled" }
            // Journal failure aborts the batch before any unjournaled move.
            try await catalog.saveHistory(entry)
            if entry.status != "cancelled" {
                var attempted = false
                do {
                    if shouldCancel { throw CancellationError() }
                    let rules = try await catalog.protections()
                    if shouldCancel { throw CancellationError() }
                    let assessment = RiskEngine.assess(record, protections: rules)
                    guard assessment.eligible else { throw StorageError.refused("error.protected") }
                    let url = URL(fileURLWithPath: record.path)
                    guard url.standardizedFileURL.path == record.path, url.resolvingSymlinksInPath().path == record.path else { throw StorageError.refused("error.symlink") }
                    let fresh = try FileMetadata.read(url)
                    guard fresh.identity == record.identity, !fresh.isSymlink, !fresh.isDirectory,
                          RiskEngine.assess(fresh, protections: rules).eligible else { throw StorageError.refused("error.changed") }
                    guard FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path) else { throw StorageError.refused("error.permission") }
                    if shouldCancel { throw CancellationError() }
                    // No suspension between final identity check and the filesystem operation.
                    guard try FileMetadata.identity(record.path) == record.identity else { throw StorageError.refused("error.changed") }
                    attempted = true
                    let destination = try operations.trash(url)
                    entry.trashPath = destination.path
                    entry.trashIdentity = try? FileMetadata.identity(destination.path)
                    entry.status = "trashed"; entry.message = "message.trashed"
                } catch is CancellationError {
                    entry.status = attempted ? "uncertain" : "cancelled"
                    entry.message = attempted ? "error.trashUncertain" : "message.cancelled"
                } catch { entry.status = attempted ? "uncertain" : "skipped"; entry.message = error.localizedDescription }
                try await catalog.saveHistory(entry)
            }
            results.append(entry)
            state.completed += 1; state.currentPath = record.path
            switch entry.status {
            case "trashed": state.moved += 1
            case "skipped": state.skipped += 1
            case "uncertain": state.uncertain += 1
            case "cancelled": state.cancelled += 1
            default: break
            }
            // Cancellation is observed between fully journaled operations.
            await progress(state)
        }
        return results
    }
    public func restore(_ original: HistoryEntry) async throws -> HistoryEntry {
        guard !busy else { throw StorageError.refused("error.busy") }
        busy = true; defer { busy = false }
        let stored = try await catalog.history()
        guard let current = stored.first(where: { $0.id == original.id }), current.status == "trashed",
              let trash = current.trashPath, let identity = current.trashIdentity else { throw StorageError.refused("error.recoveryUnavailable") }
        let source = URL(fileURLWithPath: trash), destination = URL(fileURLWithPath: current.record.path)
        guard source.resolvingSymlinksInPath().path == source.path,
              destination.deletingLastPathComponent().resolvingSymlinksInPath().path == destination.deletingLastPathComponent().path,
              try FileMetadata.identity(trash) == identity else { throw StorageError.refused("error.restoreChanged") }
        var info = stat()
        guard lstat(destination.path, &info) != 0 && errno == ENOENT else { throw StorageError.refused("error.conflict") }
        var entry = current
        entry.status = "restoring"; entry.message = "message.restoring"
        try await catalog.saveHistory(entry)
        do {
            // Journal persistence suspends execution. Recheck all filesystem assumptions
            // after it returns, with no suspension before the actual move.
            guard source.resolvingSymlinksInPath().path == source.path,
                  destination.deletingLastPathComponent().resolvingSymlinksInPath().path == destination.deletingLastPathComponent().path,
                  try FileMetadata.identity(trash) == identity else { throw StorageError.refused("error.restoreChanged") }
            var destinationInfo = stat()
            guard lstat(destination.path, &destinationInfo) != 0 && errno == ENOENT else { throw StorageError.refused("error.conflict") }
            try operations.restore(source, to: destination)
            let restored = try FileMetadata.identity(destination.path)
            // Renaming may change ctime, but must preserve file content identity and link count.
            guard restored.inode == identity.inode, restored.device == identity.device,
                  restored.size == identity.size, restored.modified == identity.modified,
                  restored.links == identity.links else { throw StorageError.refused("error.restoreUncertain") }
            entry.status = "restored"; entry.message = "message.restored"
        } catch {
            // Keep uncertain state if a move may have succeeded; do not blindly retry.
            entry.message = error.localizedDescription
            try await catalog.saveHistory(entry)
            throw error
        }
        try await catalog.saveHistory(entry)
        return entry
    }
}
