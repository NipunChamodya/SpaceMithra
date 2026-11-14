import Foundation
import CryptoKit
import Darwin

public struct DuplicateGroup: Identifiable, Sendable {
    public let id: String
    public let files: [FileRecord]
    public let totalCopies: Int
    public init(id: String, files: [FileRecord], totalCopies: Int? = nil) {
        self.id = id; self.files = files; self.totalCopies = totalCopies ?? files.count
    }
}
public struct DuplicateReport: Sendable {
    public let groups: [DuplicateGroup]
    public let issues: [ScanIssue]
    public let skippedCount: Int
    public let hashedCount: Int
    public let candidateCount: Int
    public let totalGroups: Int
}
public protocol DuplicateContentReading: Sendable {
    func digest(_ file: FileRecord) throws -> String
    func sampleDigest(_ file: FileRecord) throws -> String
}
public extension DuplicateContentReading {
    func sampleDigest(_ file: FileRecord) throws -> String { try digest(file) }
}
public struct DuplicateAnalysisProgress: Sendable {
    public let stage: String
    public let completed: Int
    public let total: Int?
    public let resumed: Bool
    public init(stage: String = "preparing", completed: Int = 0, total: Int? = nil, resumed: Bool = false) {
        self.stage = stage; self.completed = completed; self.total = total; self.resumed = resumed
    }
}
public struct SecureDuplicateHasher: DuplicateContentReading {
    public init() {}
    private func validate(_ file: FileRecord) throws {
        let fresh = try FileMetadata.read(URL(fileURLWithPath: file.path))
        guard fresh.identity == file.identity, fresh.isRegular == true, !fresh.isSymlink,
              !fresh.inPackage, !fresh.isPackage, !fresh.cloud, fresh.category != .cloud,
              fresh.identity.links == 1, fresh.identity.size >= 0 else { throw StorageError.refused("error.changed") }
    }
    public func sampleDigest(_ file: FileRecord) throws -> String {
        try validate(file)
        let descriptor = try openValidated(file); defer { close(descriptor) }
        var hash = SHA256()
        let prefix = Int(min(file.identity.size, 65536))
        let suffixStart = max(Int64(prefix), file.identity.size - 65536)
        for (offset, length) in [(Int64(0), prefix), (suffixStart, Int(file.identity.size - suffixStart))] where length > 0 {
            var bytes = [UInt8](repeating: 0, count: length), consumed = 0
            while consumed < length {
                try Task.checkCancellation()
                let n = bytes.withUnsafeMutableBytes { raw in
                    pread(descriptor, raw.baseAddress?.advanced(by: consumed), length-consumed, off_t(offset + Int64(consumed)))
                }
                if n < 0 { if errno == EINTR { continue }; throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
                guard n > 0 else { throw StorageError.refused("error.changed") }
                consumed += n
            }
            hash.update(data: Data(bytes))
        }
        try verify(descriptor, file)
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    private func verify(_ descriptor: Int32, _ file: FileRecord) throws {
        var info = stat()
        guard fstat(descriptor, &info) == 0, FileMetadata.identity(from: info) == file.identity,
              try FileMetadata.identity(file.path) == file.identity else { throw StorageError.refused("error.changed") }
        try Task.checkCancellation()
    }
    public func digest(_ file: FileRecord) throws -> String {
        try validate(file)
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
        try verify(descriptor, file)
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
    public func analyze(catalog: Catalog, status: @Sendable (DuplicateAnalysisProgress) async -> Void = { _ in }, progress: @Sendable (Int) async -> Void) async throws -> DuplicateReport {
        guard !running else { throw StorageError.refused("error.busy") }
        running = true; defer { running = false }
        await status(DuplicateAnalysisProgress())
        let run = try await catalog.beginDuplicates()
        var checks = 0
        for (state, next, stage) in [("pending", "sampled", "sampling"), ("hashing", "hashed", "hashing"), ("hashed", "verified", "verifying")] {
            if state == "hashing" { try await catalog.prepareFullHashes(run) }
            if state == "hashed" { try await catalog.prepareDuplicateVerification(run) }
            let total = try await catalog.duplicateCount(state: state)
            var completed = 0
            await status(DuplicateAnalysisProgress(stage: stage,total: total,resumed: run.resumed))
            while true {
                try Task.checkCancellation()
                let batch = try await catalog.duplicateBatch(run,state: state)
                if batch.isEmpty { break }
                var updates: [DuplicateWorkUpdate] = []
                for file in batch {
                    try Task.checkCancellation()
                    do {
                        if state == "pending" {
                            updates.append(DuplicateWorkUpdate(path:file.path,state:next,sample:try reader.sampleDigest(file)))
                        } else if state == "hashing" {
                            updates.append(DuplicateWorkUpdate(path:file.path,state:next,hash:try reader.digest(file)))
                        } else {
                            let url = URL(fileURLWithPath:file.path)
                            let fresh = try FileMetadata.read(url)
                            guard url.resolvingSymlinksInPath().path == file.path, fresh.identity == file.identity,
                                  fresh.isRegular == true, !fresh.cloud, fresh.category != .cloud,
                                  !fresh.inPackage, !fresh.isPackage else { throw StorageError.refused("error.changed") }
                            updates.append(DuplicateWorkUpdate(path:file.path,state:next))
                        }
                    } catch is CancellationError { throw CancellationError() }
                    catch { updates.append(DuplicateWorkUpdate(path:file.path,state:"skipped",message:error.localizedDescription)) }
                    completed += 1; checks += 1
                    await progress(checks)
                }
                try await catalog.saveDuplicateUpdates(run,updates:updates)
                await status(DuplicateAnalysisProgress(stage:stage,completed:completed,total:total,resumed:run.resumed))
            }
        }
        try Task.checkCancellation()
        try await catalog.publishDuplicates(run)
        try Task.checkCancellation()
        let report = try await catalog.duplicateReport()
        await status(DuplicateAnalysisProgress(stage:"completed",completed:report.candidateCount,total:report.candidateCount,resumed:run.resumed))
        return report
    }
}
