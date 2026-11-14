import Foundation

public actor StorageScanner {
    private var paused = false
    private var cancelled = false
    private var running = false
    public init() {}
    public func pause(_ value: Bool) { paused = value }
    public func cancel() { cancelled = true }
    private func shouldStop() -> Bool { cancelled || Task.isCancelled }
    public func scan(root inputRoot: URL, catalog: Catalog, update: @Sendable (ScanProgress) async -> Void) async throws -> ScanProgress {
        guard !running else { throw StorageError.refused("error.busy") }
        running = true; defer { running = false }
        paused = false; cancelled = false
        var progress = ScanProgress(); progress.state = .preparing
        await update(progress)
        let root = try FileLocation.validated(inputRoot)
        let rootRecord = try FileMetadata.read(root)
        guard rootRecord.isDirectory, !rootRecord.isSymlink, root.resolvingSymlinksInPath().path == root.standardizedFileURL.path else { throw StorageError.refused("error.scanRoot") }
        try await catalog.resetScan()
        try await catalog.saveScanContext(ScanCatalogContext(root:root.path,state:.scanning,started:progress.started,count:0,errors:0))
        try await catalog.insert([rootRecord])
        _ = try await catalog.registerDirectory(rootRecord.identity)
        let dataDevice = root.path == "/" ? (try? FileMetadata.identity("/System/Volumes/Data").device) : nil
        progress.state = .scanning
        // DirectoryEnumerator streams URLs. Files are flushed to SQLite in bounded batches.
        let errorCounter = ScanErrors()
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey], options: [], errorHandler: { url, error in errorCounter.append(url.path, error.localizedDescription); return true }) else { throw StorageError.refused("error.scanUnreadable") }
        var batch: [FileRecord] = []
        var packagePaths: [String] = rootRecord.isPackage || rootRecord.inPackage ? [root.path] : []
        var lastUpdate = Date.distantPast
        while let url = enumerator.nextObject() as? URL {
            if cancelled || Task.isCancelled { progress.state = .cancelled; break }
            while paused && !cancelled && !Task.isCancelled {
                progress.state = .paused; await update(progress)
                try? await Task.sleep(for: .milliseconds(150))
            }
            if cancelled || Task.isCancelled { progress.state = .cancelled; break }
            progress.state = .scanning
            do {
                packagePaths.removeAll { !url.path.hasPrefix($0 + "/") }
                if root.path == "/", ["/System/Volumes", "/Volumes", "/dev", "/net"].contains(url.path) {
                    enumerator.skipDescendants(); continue
                }
                let identity = try FileMetadata.identity(url.path)
                if identity.device != rootRecord.identity.device && identity.device != dataDevice {
                    enumerator.skipDescendants()
                    try await catalog.saveScanIssue(ScanIssue(path: url.path, message: "scan.otherVolume"))
                    continue
                }
                let record: FileRecord
                if var cached = try await catalog.cachedRecord(path: url.path, identity: identity) {
                    cached.inPackage = !packagePaths.isEmpty; cached.category = Classifier.category(url,cloud:cached.cloud); record = cached; progress.reused += 1
                } else {
                    record = try FileMetadata.read(url, inPackage: !packagePaths.isEmpty, inspectAncestors: false)
                }
                if record.isDirectory && !record.isSymlink {
                    let firstVisit = try await catalog.registerDirectory(record.identity)
                    if !firstVisit { enumerator.skipDescendants(); continue }
                }
                if record.isSymlink { enumerator.skipDescendants() }
                if record.isPackage { packagePaths.append(record.path) }
                // Count an inode only once without an unbounded in-memory identity set.
                // A second stat detects common concurrent modifications.
                guard try FileMetadata.identity(record.path) == record.identity else { throw StorageError.refused("error.changed") }
                progress.count += 1
                let (bytes,overflow) = progress.bytes.addingReportingOverflow(record.logical)
                progress.bytes = overflow ? Int64.max : bytes; progress.current = record.path
                batch.append(record)
            } catch StorageError.database(let message) { throw StorageError.database(message) }
            catch {
                progress.errors += 1
                try await catalog.saveScanIssue(ScanIssue(path: url.path, message: error.localizedDescription))
            }
            let enumerationErrors = errorCounter.take()
            progress.errors += enumerationErrors.0
            for issue in enumerationErrors.1 { try await catalog.saveScanIssue(issue) }
            // Database failures abort the scan rather than growing a failed batch in memory.
            if batch.count >= 128 { try await catalog.insert(batch); batch.removeAll(keepingCapacity: true) }
            if Date().timeIntervalSince(lastUpdate) > 0.15 {
                await update(progress); lastUpdate = Date()
                await Task.yield()
            }
        }
        if !batch.isEmpty { try await catalog.insert(batch) }
        do { try await catalog.aggregateDirectories(shouldCancel: { await self.shouldStop() }) }
        catch is CancellationError { progress.state = .cancelled }
        let remaining = errorCounter.take()
        progress.errors += remaining.0
        for issue in remaining.1 { try await catalog.saveScanIssue(issue) }
        progress.bytes = try await catalog.totalBytes()
        if cancelled || Task.isCancelled { progress.state = .cancelled }
        if progress.state != .cancelled { progress.state = .completed; try await catalog.recordTrend(bytes: progress.bytes) }
        try await catalog.saveScanContext(ScanCatalogContext(root:root.path,state:progress.state,started:progress.started,finished:Date(),count:progress.count,errors:progress.errors))
        await update(progress)
        return progress
    }
}
private final class ScanErrors: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var issues: [ScanIssue] = []
    func append(_ path: String, _ message: String) {
        lock.lock(); defer { lock.unlock() }
        count += 1
        if issues.count < 128 { issues.append(ScanIssue(path: path, message: message)) }
    }
    func take() -> (Int, [ScanIssue]) {
        lock.lock(); defer { lock.unlock() }
        let result = (count, issues); count = 0; issues.removeAll(keepingCapacity: true); return result
    }
}
