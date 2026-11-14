import Foundation

public enum ScanState: String, Codable, Sendable { case idle, preparing, scanning, paused, completed, cancelled, failed }
public enum FileCategory: String, CaseIterable, Codable, Sendable {
    case applications, documents, images, videos, audio, archives, installers, caches, logs, backups, developer, support, cloud, unknown
}
public enum Risk: String, Codable, Sendable { case low, reviewRequired, protected, unknown }
public struct Identity: Codable, Equatable, Sendable {
    public var device: UInt64
    public var inode: UInt64
    public var size: Int64
    public var modified: Double
    public var changed: Double
    public var links: UInt64
}
public struct FileRecord: Codable, Identifiable, Sendable, Equatable {
    public var id: String { path }
    public var path: String
    public var parent: String
    public var name: String
    public var isDirectory: Bool
    public var isRegular: Bool?
    public var isSymlink: Bool
    public var inPackage: Bool
    public var isPackage: Bool
    public var logical: Int64
    public var allocated: Int64?
    public var created: Date?
    public var modified: Date?
    public var opened: Date?
    public var identity: Identity
    public var category: FileCategory
    public var typeIdentifier: String?
    public var cloud: Bool
}
public struct ScanProgress: Sendable {
    public var state: ScanState = .idle
    public var count = 0
    public var reused = 0
    public var bytes: Int64 = 0
    public var errors = 0
    public var current = ""
    public var started = Date()
    public init() {}
}
public struct Assessment: Sendable {
    public var risk: Risk
    public var explanation: String
    public var consequence: String
    public var eligible: Bool
}
public struct Protection: Codable, Identifiable, Sendable {
    public var id: String
    public var path: String
    public var descendants: Bool
    public var expires: Date?
    public init(path: String, descendants: Bool, expires: Date? = nil) {
        self.id = UUID().uuidString; self.path = path; self.descendants = descendants; self.expires = expires
    }
    public func matches(_ candidate: String) -> Bool {
        guard expires.map({ $0 > Date() }) ?? true else { return false }
        return candidate == path || (descendants && FileLocation.contains(candidate,within:path))
    }
}
public struct HistoryEntry: Codable, Identifiable, Sendable {
    public var id: String
    public var session: String
    public var record: FileRecord
    public var trashPath: String?
    public var trashIdentity: Identity?
    public var date: Date
    public var status: String
    public var message: String
}
public enum StorageError: LocalizedError {
    case refused(String), database(String)
    public var errorDescription: String? {
        switch self { case .refused(let message), .database(let message): return message }
    }
}
public func byteString(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

public struct ScanIssue: Identifiable, Sendable {
    public var id = UUID().uuidString
    public var path: String
    public var message: String
}

public struct CleanupProgress: Sendable {
    public var total: Int
    public var completed = 0
    public var moved = 0
    public var skipped = 0
    public var uncertain = 0
    public var cancelled = 0
    public var currentPath = ""
    public init(total: Int) { self.total = total }
}

/// Lock-protected request state only; safe to request before an actor starts a batch.
/// No filesystem operation is interrupted by this token.
public final class CleanupCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var requested = false
    public init() {}
    public func cancel() { lock.lock(); requested = true; lock.unlock() }
    public var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return requested }
}
