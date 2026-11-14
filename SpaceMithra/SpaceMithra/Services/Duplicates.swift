import Foundation
import CryptoKit
import Darwin

public struct DuplicateGroup: Identifiable, Sendable {
    public let id: String
    public let files: [FileRecord]
}
public struct DuplicateReport: Sendable {
    public let groups: [DuplicateGroup]
    public let issues: [ScanIssue]
    public let skippedCount: Int
    public let hashedCount: Int
}
public protocol DuplicateContentReading: Sendable {
    func digest(_ file: FileRecord) throws -> String
}
public struct SecureDuplicateHasher: DuplicateContentReading {
    public init() {}
    public func digest(_ file: FileRecord) throws -> String {
        let fresh = try FileMetadata.read(URL(fileURLWithPath: file.path))
        guard fresh.identity == file.identity, fresh.isRegular == true, !fresh.isSymlink,
              !fresh.inPackage, !fresh.isPackage, !fresh.cloud, fresh.category != .cloud,
              fresh.identity.links == 1, fresh.identity.size >= 0 else { throw StorageError.refused("error.changed") }
        let descriptor = try openValidated(file)
        defer { close(descriptor) }
        var hasher = SHA256()
        var remaining = file.identity.size
        var buffer = [UInt8](repeating: 0, count: 1024 * 1024)
        // Read at most the reviewed length, even if another process keeps appending.
        while remaining > 0 {
            try Task.checkCancellation()
            let limit = Int(min(remaining, 1024 * 1024))
            let count = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(descriptor, bytes.baseAddress, limit)
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            guard count > 0 else { throw StorageError.refused("error.changed") }
            hasher.update(data: Data(buffer.prefix(count)))
            remaining -= Int64(count)
        }
        var after = stat()
        guard fstat(descriptor, &after) == 0, FileMetadata.identity(from: after) == file.identity,
              try FileMetadata.identity(file.path) == file.identity else { throw StorageError.refused("error.changed") }
        try Task.checkCancellation()
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
    /// Bind each parent component with openat; no ancestor or leaf symlink is followed.
    /// NONBLOCK prevents an unexpected FIFO replacement from blocking before fstat.
    func openValidated(_ file: FileRecord) throws -> Int32 {
        let url = URL(fileURLWithPath: file.path)
        let components = file.path.split(separator: "/").map(String.init)
        guard file.path.hasPrefix("/"), url.standardizedFileURL.path == file.path,
              let leaf = components.last else { throw StorageError.refused("error.symlink") }
        var parent = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard parent >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(parent) }
        for component in components.dropLast() {
            let next = openat(parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard next >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            close(parent); parent = next
        }
        let descriptor = openat(parent, leaf, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var info = stat()
        guard fstat(descriptor, &info) == 0,
              info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              FileMetadata.identity(from: info) == file.identity else {
            close(descriptor); throw StorageError.refused("error.changed")
        }
        return descriptor
    }
}

public actor DuplicateDetector {
    private let reader: any DuplicateContentReading
    private var running = false
    public init(reader: any DuplicateContentReading = SecureDuplicateHasher()) { self.reader = reader }
    public func find(catalog: Catalog, progress: @Sendable (Int) async -> Void) async throws -> [DuplicateGroup] {
        try await analyze(catalog: catalog, progress: progress).groups
    }
    public func analyze(catalog: Catalog, progress: @Sendable (Int) async -> Void) async throws -> DuplicateReport {
        guard !running else { throw StorageError.refused("error.busy") }
        running = true; defer { running = false }
        var offset = 0, count = 0
        var candidates: [Int64: [FileRecord]] = [:]
        while true {
            try Task.checkCancellation()
            let page = try await catalog.list(biggest: true, offset: offset, limit: 500)
            if page.isEmpty { break }
            for file in page where file.logical > 0 && file.isRegular == true && !file.isSymlink && !file.inPackage && !file.isPackage && !file.cloud && file.category != .cloud && file.identity.links == 1 {
                candidates[file.logical, default: []].append(file)
                count += 1
                if count > 20000 { throw StorageError.refused("error.duplicateLimit") }
            }
            offset += page.count
        }
        var hashed: [String: [FileRecord]] = [:], issues: [ScanIssue] = []
        var processed = 0, hashedCount = 0, skipped = 0
        func recordIssue(_ file: FileRecord, _ error: Error) {
            skipped += 1
            if issues.count < 200 { issues.append(ScanIssue(path: file.path, message: error.localizedDescription)) }
        }
        for size in candidates.keys.sorted(by: >) {
            guard let group = candidates[size], group.count > 1 else { continue }
            for file in group.sorted(by: { $0.path < $1.path }) {
                try Task.checkCancellation()
                do {
                    let hash = String(file.identity.size) + ":" + (try reader.digest(file))
                    hashed[hash, default: []].append(file); hashedCount += 1
                } catch is CancellationError { throw CancellationError() }
                catch { recordIssue(file, error) }
                processed += 1; await progress(processed)
            }
        }
        var result: [DuplicateGroup] = []
        // Earlier hashes can become stale while subsequent files are read or progress yields.
        // Final validation removes those paths before displaying any duplicate group.
        for hash in hashed.keys.sorted() {
            var verified: [FileRecord] = []
            for file in hashed[hash] ?? [] {
                try Task.checkCancellation()
                do {
                    let url = URL(fileURLWithPath: file.path)
                    let fresh = try FileMetadata.read(url)
                    guard url.resolvingSymlinksInPath().path == file.path, fresh.identity == file.identity,
                          fresh.isRegular == true, !fresh.cloud, fresh.category != .cloud,
                          !fresh.inPackage, !fresh.isPackage else { throw StorageError.refused("error.changed") }
                    verified.append(file)
                } catch { recordIssue(file, error) }
            }
            if verified.count > 1 { result.append(DuplicateGroup(id: hash, files: verified)) }
        }
        try Task.checkCancellation()
        result.sort {
            let a = $0.files.first?.logical ?? 0, b = $1.files.first?.logical ?? 0
            return a == b ? $0.id < $1.id : a > b
        }
        return DuplicateReport(groups: result, issues: issues, skippedCount: skipped, hashedCount: hashedCount)
    }
}
