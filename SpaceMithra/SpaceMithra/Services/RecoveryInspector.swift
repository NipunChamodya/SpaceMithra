import Foundation

public enum RecoveryAvailability: String, Sendable {
    case available, missing, changed, conflict, unverified, notApplicable
}
public struct RecoveryCheck: Sendable {
    public let availability: RecoveryAvailability
    public let date: Date
    public var canRestore: Bool { availability == .available }
}
/// A point-in-time, read-only check. The restore engine repeats validation after approval.
public actor RecoveryInspector {
    public init() {}
    public func check(_ entries: [HistoryEntry]) async throws -> [String: RecoveryCheck] {
        var results: [String: RecoveryCheck] = [:]
        for entry in entries {
            try Task.checkCancellation()
            results[entry.id] = RecoveryCheck(availability: inspect(entry), date: Date())
        }
        return results
    }
    private func inspect(_ entry: HistoryEntry) -> RecoveryAvailability {
        guard entry.status == "trashed" else { return .notApplicable }
        guard let path = entry.trashPath, let expected = entry.trashIdentity else { return .unverified }
        do {
            let actual = try FileMetadata.identity(path)
            let source = URL(fileURLWithPath: path)
            guard actual == expected, source.resolvingSymlinksInPath().path == path else { return .changed }
            let destination = URL(fileURLWithPath: entry.record.path)
            let parent = destination.deletingLastPathComponent()
            guard parent.resolvingSymlinksInPath().path == parent.path else { return .changed }
            let metadata = try FileMetadata.read(parent)
            guard metadata.isDirectory, !metadata.isSymlink else { return .unverified }
            var info = stat()
            if lstat(destination.path, &info) == 0 { return .conflict }
            guard errno == ENOENT else { return .unverified }
            guard FileManager.default.isWritableFile(atPath: parent.path) else { return .unverified }
            return .available
        } catch let error as POSIXError where error.code == .ENOENT {
            // Only absence of the recorded Trash path establishes that the item is missing.
            var info = stat()
            return lstat(path, &info) != 0 && errno == ENOENT ? .missing : .unverified
        } catch { return .unverified }
    }
}
