import Foundation

public protocol TrashOperations: Sendable {
    func trash(_ url: URL) throws -> URL
    func restore(_ source: URL, to destination: URL) throws
}
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
    private let catalog: Catalog
    private let operations: any TrashOperations
    private var busy = false
    public init(catalog: Catalog, operations: any TrashOperations = SystemTrash()) { self.catalog = catalog; self.operations = operations }
    public func clean(confirmed records: [FileRecord]) async throws -> [HistoryEntry] {
        guard !busy else { throw StorageError.refused("error.busy") }
        busy = true; defer { busy = false }
        let session = UUID().uuidString
        var results: [HistoryEntry] = []
        for record in records {
            var entry = HistoryEntry(id: UUID().uuidString, session: session, record: record, date: Date(), status: "pending", message: "message.pending")
            // Journal failure aborts the batch before any unjournaled move.
            try await catalog.saveHistory(entry)
            var attempted = false
            do {
                let rules = try await catalog.protections()
                let assessment = RiskEngine.assess(record, protections: rules)
                guard assessment.eligible else { throw StorageError.refused("error.protected") }
                let url = URL(fileURLWithPath: record.path)
                guard url.standardizedFileURL.path == record.path, url.resolvingSymlinksInPath().path == record.path else { throw StorageError.refused("error.symlink") }
                let fresh = try FileMetadata.read(url)
                guard fresh.identity == record.identity, !fresh.isSymlink, !fresh.isDirectory,
                      RiskEngine.assess(fresh, protections: rules).eligible else { throw StorageError.refused("error.changed") }
                guard FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path) else { throw StorageError.refused("error.permission") }
                // No suspension between final identity check and the filesystem operation.
                guard try FileMetadata.identity(record.path) == record.identity else { throw StorageError.refused("error.changed") }
                attempted = true
                let destination = try operations.trash(url)
                entry.trashPath = destination.path
                entry.trashIdentity = try? FileMetadata.identity(destination.path)
                entry.status = "trashed"; entry.message = "message.trashed"
            } catch { entry.status = attempted ? "uncertain" : "skipped"; entry.message = error.localizedDescription }
            try await catalog.saveHistory(entry)
            results.append(entry)
        }
        return results
    }
    public func restore(_ original: HistoryEntry) async throws -> HistoryEntry {
        guard !busy else { throw StorageError.refused("Another operation is in progress") }
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
            try operations.restore(source, to: destination)
            let restored = try FileMetadata.identity(destination.path)
            guard restored.inode == identity.inode, restored.device == identity.device, restored.size == identity.size else { throw StorageError.refused("error.restoreUncertain") }
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
