import SwiftUI
import AppKit
#if canImport(SpaceMithraCore)
import SpaceMithraCore
#endif

@MainActor final class AppModel: ObservableObject {
    @Published var scanDisk: DiskCapacitySnapshot?
    @Published var scanWasInterrupted = false
    @Published var categoryBuckets: [String:Int64] = [:]
    @Published var reviewSuggestions: [ReviewSuggestion] = []
    @Published var startupDisk: DiskCapacitySnapshot?
    @Published var mountedVolumes: [StorageVolume] = []
    @Published var storageSummary = ScanStorageSummary()
    @Published var lastScanDate: Date?
    @Published var applications: [ApplicationStorage] = []
    @Published var loadingApplications = false
    @Published var developerEntries: [DeveloperStorageEntry] = []
    @Published var loadingDeveloper = false
    @Published var catalog: Catalog?
    @Published var scanIssues: [ScanIssue] = []
    @Published var progress = ScanProgress()
    @Published var root: URL?
    @Published var folder: String?
    @Published var rows: [FileRecord] = []
    @Published var columns: [(String, [FileRecord])] = []
    @Published var selection: String?
    @Published private(set) var cleanupReview: CleanupReview?
    @Published var queue: [FileRecord] = []
    @Published var protections: [Protection] = []
    @Published private(set) var recoveryChecks: [String: RecoveryCheck] = [:]
    @Published private(set) var checkingRecovery = false
    @Published private(set) var preparingReview = false
    @Published var history: [HistoryEntry] = []
    @Published var duplicates: [DuplicateGroup] = []
    @Published var discoveredStorage: [DiscoveredStorage] = []
    @Published var storageGroup: String?
    @Published var trends: [(Date, Int64)] = []
    @Published var section = "dashboard"
    @Published var search = ""
    @Published var analysisPathPrefix: String?
    @Published var overviewBucket: String?
    @Published var category: FileCategory?
    @Published var sort = "size"
    @Published var showHidden = false
    @Published var errorDetails: String?
    @Published var error: String?
    @Published var working = false
    @Published private(set) var cleaning = false
    @Published private(set) var cleanupCancellationRequested = false
    @Published private(set) var cleanupProgress = CleanupProgress(total: 0)
    @Published var duplicateAnalysis = DuplicateAnalysisProgress()
    @Published var duplicateResumeAvailable = false
    @Published var duplicateTotalGroups = 0
    @Published var duplicateGroupPage = 0
    @Published var duplicateMemberPages: [String: Int] = [:]
    @Published var duplicateIssues: [ScanIssue] = []
    @Published var duplicateSkipped = 0
    @Published var duplicateCount = 0
    @Published var page = 0
    @Published var hasMore = false
    @Published var minimumMB = "0"
    @Published var extensionFilter = ""
    @Published var modifiedBefore: Date?
    @Published var modifiedSince = Date.distantPast
    @Published var duplicateWorking = false
    @AppStorage("showAdvanced") var showAdvanced = false
    @AppStorage("developerMode") var developerMode = false
    @AppStorage("language") var language = "si"
    private let scanner = StorageScanner()
    private var cleanup: CleanupEngine?
    private var cleanupCancellation: CleanupCancellation?
    private var scanTask: Task<Void, Never>?
    private var duplicateTask: Task<Void, Never>?
    private var reviewTask: Task<CleanupReview, Error>?
    private var recoveryCheckID = UUID()
    private var scope: URL?
    private var refreshID = UUID()
    init(catalog: Catalog? = nil, cleanup: CleanupEngine? = nil) {
        self.catalog = catalog; self.cleanup = cleanup
    }
    var selected: FileRecord? { rows.first { $0.path == selection } ?? queue.first { $0.path == selection } }
    var scanning: Bool { [.preparing, .scanning, .paused].contains(progress.state) }
    var historySessions: [CleanupHistorySession] { CleanupHistorySession.group(history) }
    var queuedBytes: Int64 {
        queue.reduce(0) { total, file in
            let (sum, overflow) = total.addingReportingOverflow(max(0, file.logical))
            return overflow ? Int64.max : sum
        }
    }
    func text(_ key: String) -> String {
        Self.localized(key, language: language, bundle: .main)
    }
    static func localized(_ key: String, language: String, bundle: Bundle) -> String {
        let english = bundle.path(forResource: "en", ofType: "lproj").flatMap { Bundle(path: $0) }
        let fallback = english?.localizedString(forKey: key, value: key, table: nil) ?? key
        guard let path = bundle.path(forResource: language, ofType: "lproj"), let selected = Bundle(path: path) else { return fallback }
        return selected.localizedString(forKey: key, value: fallback, table: nil)
    }
    private func describe(_ error: Error) -> String {
        errorDetails=nil
        if case StorageError.refused(let key)=error {return text(key)}
        if case StorageError.database(let details)=error {errorDetails=details;return text("error.database")}
        let ns=error as NSError
        errorDetails=ns.localizedDescription
        if (ns.domain == NSPOSIXErrorDomain && [Int(EACCES),Int(EPERM)].contains(ns.code)) || (ns.domain == NSCocoaErrorDomain && ns.code == NSFileReadNoPermissionError) {return text("error.permissionFriendly")}
        return text("error.operationFriendly")
    }
    private var isUITesting:Bool {ProcessInfo.processInfo.arguments.contains("--ui-testing")}
    private var uiFixture:URL? {
        let args=ProcessInfo.processInfo.arguments
        guard isUITesting,let index=args.firstIndex(of:"--ui-fixture-root"),args.indices.contains(index+1),
              let url=try? FileLocation.fileURL(path:args[index+1]),
              FileLocation.contains(url.resolvingSymlinksInPath().path,within:URL(fileURLWithPath:"/private/tmp/SpaceMithra-UITest-Fixtures",isDirectory:true).resolvingSymlinksInPath().path) else {return nil}
        return url
    }
    func start() async {
        guard catalog == nil else { return }
        let volumes = VolumeService()
        mountedVolumes = await volumes.discover()
        do { startupDisk = try await volumes.startupCapacity() } catch { self.error = describe(error) }
        do {
            let support: URL
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                support = FileManager.default.temporaryDirectory.appendingPathComponent("SpaceMithra-UITests/" + UUID().uuidString)
            } else {
                support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            }
            let databaseURL = support.appendingPathComponent("SpaceMithra/catalog.sqlite")
            let db = try await Task.detached(priority: .userInitiated) { try Catalog(url: databaseURL) }.value
            catalog = db; cleanup = isUITesting ? CleanupEngine(catalog:db,operations:UITestReadOnlyOperations()) : CleanupEngine(catalog: db)
            try await loadPersistent()
            if let context=try await db.scanContext() {
                root=try FileLocation.fileURL(path:context.root);folder=root?.path
                progress.state=context.state;progress.started=context.started;progress.count=context.count;progress.errors=context.errors;progress.bytes=storageSummary.logical
                lastScanDate=context.finished
                if [.preparing,.scanning,.paused].contains(context.state) {scanWasInterrupted=true;progress.state = .cancelled}
                if let root {scanDisk=try? await volumes.capacity(at:root)}
                await refresh()
            }
            if let fixture=uiFixture,ProcessInfo.processInfo.arguments.contains("--ui-auto-scan") {scan(fixture,destination:"dashboard")}
        } catch { self.error = describe(error) }
    }
    func loadPersistent() async throws {
        guard let catalog else { return }
        protections = try await catalog.protections()
        history = try await catalog.history().sorted { $0.date > $1.date }
        trends = try await catalog.trends()
        discoveredStorage = try await catalog.discoveredStorage()
        scanIssues = try await catalog.scanIssues()
        storageSummary = try await catalog.storageSummary()
        categoryBuckets = try await catalog.dashboardBuckets()
        reviewSuggestions = try await catalog.suggestions()
        duplicateResumeAvailable = try await catalog.canResumeDuplicates()
        await refreshRecoveryAvailability()
    }
    func byteText(_ bytes:Int64)->String {
        bytes.formatted(ByteCountFormatStyle(style:.file,spellsOutZero:false).locale(Locale(identifier:language)))
    }
    func dateText(_ date:Date)->String {date.formatted(.dateTime.locale(Locale(identifier:language)))}
    func capacityText(_ bytes:Int64)->String {
        (Double(bytes)/1_000_000_000).formatted(.number.locale(Locale(identifier:language)).precision(.fractionLength(1))) + " GB"
    }
    func scanMyMac() {scan(URL(fileURLWithPath:"/",isDirectory:true),destination:"dashboard")}
    func openCategory(_ key:String) {
        if key == "applications" {switchSection("applications");return}
        if key == "downloads" {openStorageLocation(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads",isDirectory:true));return}
        analysisPathPrefix=nil
        section="biggest";search="";minimumMB="0";extensionFilter="";modifiedSince = .distantPast;modifiedBefore=nil;storageGroup=nil;page=0
        category=FileCategory(rawValue:key);overviewBucket=key
        if key == "other" {category=nil}
        Task{await refresh()}
    }
    func openSuggestion(_ id:String) {
        if id == "installers" {openCategory("installers");overviewBucket=nil;analysisPathPrefix=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads",isDirectory:true).path;modifiedBefore=Date().addingTimeInterval(-30*86400)}
        else if id == "videos" {openCategory("videos");overviewBucket=nil;minimumMB="100"}
        else if id == "caches" {switchSection("caches")}
        Task{await refresh()}
    }
    func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false; panel.prompt = text("scan")
        if panel.runModal() == .OK, let url = panel.url { scan(url) }
    }
    func scan(_ inputURL: URL, destination: String = "explorer") {
        guard !scanning, !working, !duplicateWorking, let catalog else { return }
        let url: URL
        do { url = try FileLocation.validated(inputURL)
            guard FileManager.default.isReadableFile(atPath: url.path) else { throw StorageError.refused("error.scanUnreadable") }
        } catch { self.error = describe(error); return }
        scope?.stopAccessingSecurityScopedResource(); scope = nil
        if inputURL.startAccessingSecurityScopedResource() { scope = inputURL }
        root = url; folder = url.path; section = "explorer"; rows = []; columns = []; storageSummary = ScanStorageSummary(); lastScanDate = nil; scanWasInterrupted = false; scanDisk = nil; categoryBuckets = [:]; reviewSuggestions = []; search = ""; category = nil; overviewBucket = nil; analysisPathPrefix = nil; storageGroup = nil; modifiedBefore = nil; selection = nil; duplicates = []; duplicateIssues = []; duplicateSkipped = 0; page = 0
        progress = ScanProgress(); progress.state = .preparing
        scanTask = Task {
            do {
                scanDisk = try? await VolumeService().capacity(at:url)
                progress = try await scanner.scan(root: url, catalog: catalog) { [weak self] p in
                    await MainActor.run { self?.progress = p }
                }
                lastScanDate = Date()
                section = destination
                await refresh(); try await loadPersistent()
            } catch {
                progress.state = .failed; lastScanDate=Date(); self.error = describe(error)
                if var context=try? await catalog.scanContext(), context.root == url.path {context.state = .failed;context.errors=progress.errors;context.count=progress.count;context.finished=Date();try? await catalog.saveScanContext(context)}
            }
        }
    }
    func pause() { let value = progress.state != .paused; Task { await scanner.pause(value) } }
    func cancel() {
        if cleaning { cancelCleanup() }
        else if preparingReview { cancelCleanupReview() }
        else if duplicateWorking { cancelDuplicates() }
        else { Task { await scanner.cancel() } }
    }
    var diskAccounting:DiskScanAccounting? {
        guard let startupDisk else {return nil}
        let same=scanDisk.map{$0.volumeURL.path == startupDisk.volumeURL.path || $0.volumeURL.path == "/System/Volumes/Data"} ?? false
        return DiskScanAccounting(disk:startupDisk,allocatedKnown:root == nil ? nil:storageSummary.allocatedKnown,sameStartupStorage:same)
    }
    var canNavigateParent: Bool {
        guard let folder, let root else { return false }
        return (try? FileLocation.parent(of: URL(fileURLWithPath: folder, isDirectory: true), within: root)) != nil
    }
    func navigateParent() {
        guard let folder, let root else { return }
        do { if let parent = try FileLocation.parent(of: URL(fileURLWithPath: folder, isDirectory: true), within: root) { navigate(parent.path) } }
        catch { self.error = describe(error) }
    }
    func navigate(_ path: String) {
        guard let root else { return }
        do {
            let url = try FileLocation.fileURL(path: path)
            guard FileLocation.contains(url.path, within: root.path) else { throw StorageError.refused("error.invalidLocation") }
            let record = try FileMetadata.read(url)
            guard record.isDirectory, !record.isSymlink, FileManager.default.isReadableFile(atPath: url.path) else { throw StorageError.refused("error.scanUnreadable") }
            folder = url.path; section = "explorer"; selection = nil; page = 0; overviewBucket = nil; analysisPathPrefix = nil; category = nil; modifiedBefore = nil; search = ""
            Task { await refresh() }
        } catch { self.error = describe(error) }
    }
    func switchSection(_ value: String) { section = value; storageGroup = nil; overviewBucket = nil; analysisPathPrefix = nil; modifiedBefore = nil; selection = nil; page = 0; Task { await refresh(); if value == "recovery" { await refreshRecoveryAvailability() } } }
    func refresh() async {
        guard let catalog else { return }
        let request = UUID(); refreshID = request
        do {
            let filter: FileCategory? = storageGroup != nil ? nil : section == "caches" ? .caches : section == "developer" ? nil : category
            let parent = section == "explorer" && search.isEmpty ? folder : nil
            let parsed = Double(minimumMB) ?? 0
            let minimum = parsed.isFinite && parsed >= 0 ? min(parsed * 1_000_000,Double(Int64.max)) : 0
            let minimumBytes = minimum >= Double(Int64.max) ? Int64.max : Int64(minimum)
            let records = try await catalog.list(parent: parent, search: search, category: filter,
                biggest: ["biggest", "caches", "developer"].contains(section), sort: sort, pathPrefix: analysisPathPrefix ?? discoveredStorage.first(where: { $0.id == storageGroup })?.rule.path, developerOnly: section == "developer" && storageGroup == nil, minimumSize: section == "biggest" ? minimumBytes : 0, extensionFilter: section == "biggest" ? extensionFilter : "", modifiedAfter: section == "biggest" && modifiedSince != .distantPast ? modifiedSince : nil, modifiedBefore: modifiedBefore, showHidden: showHidden, overviewBucket: overviewBucket, offset: page * 300, limit: 301)
            guard request == refreshID else { return }
            hasMore = records.count > 300
            rows = Array(records.prefix(300))
            if section == "explorer", let folder, let root {
                let paths = try FileLocation.breadcrumbs(to: URL(fileURLWithPath: folder, isDirectory: true), within: root).suffix(3).map(\.path)
                var loaded: [(String, [FileRecord])] = []
                for path in paths {
                    let children = try await catalog.list(parent: path, sort: "name", directoriesOnly: true, showHidden: showHidden, limit: 150)
                    loaded.append((path, children.filter { showHidden || !$0.name.hasPrefix(".") }))
                }
                guard request == refreshID else { return }
                columns = loaded
            }

        } catch { self.error = describe(error) }
    }
    func assessment(_ file: FileRecord) -> Assessment { RiskEngine.assess(file, protections: protections) }
    func enqueue(_ file: FileRecord) {
        guard !scanning, !working, !duplicateWorking, progress.state == .completed, assessment(file).eligible, !queue.contains(where: { $0.path == file.path }) else { return }
        // The same rule applies from every screen, including bulk page selection.
        for group in duplicates where group.totalCopies == group.files.count && group.files.contains(where: { $0.path == file.path }) {
            let selected = Set(queue.map(\.path)).union([file.path])
            guard !group.files.allSatisfy({ selected.contains($0.path) }) else { return }
        }
        queue.append(file)
    }
    func keep(_ file: FileRecord) { queue.removeAll { $0.path == file.path } }
    func protect(_ file: FileRecord, temporary: Bool = false) {
        Task {
            do {
                try await catalog?.saveProtection(Protection(path: file.path, descendants: file.isDirectory, expires: temporary ? Date().addingTimeInterval(86400) : nil))
                keep(file); try await loadPersistent()
            } catch { self.error = describe(error) }
        }
    }
    func unprotect(_ rule: Protection) {
        Task { do { try await catalog?.removeProtection(rule.id); try await loadPersistent() } catch { self.error = describe(error) } }
    }
    func prepareCleanupReview(using journal: (any CleanupJournal)? = nil) async {
        guard !scanning, !working, !duplicateWorking, let source = journal ?? catalog else { return }
        working = true; preparingReview = true; cleanupReview = nil
        defer { working = false; preparingReview = false; reviewTask = nil }
        let selected = queue
        guard preservesDuplicateCopy(selected) else { self.error = text("duplicate.keepOne"); return }
        let task = Task { try await CleanupReviewer().review(selected, journal: source) }
        reviewTask = task
        do {
            let review = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
            guard !task.isCancelled else { return }
            guard queue == selected else { throw StorageError.refused("error.changed") }
            cleanupReview = review
        } catch is CancellationError {
            // Cancelling preflight never creates an approval or a history entry.
        } catch { self.error = describe(error) }
    }
    func cancelCleanupReview() { reviewTask?.cancel(); cleanupReview = nil }
    func refreshRecoveryAvailability() async {
        let token = UUID(); recoveryCheckID = token; checkingRecovery = true
        defer { if recoveryCheckID == token { checkingRecovery = false } }
        do {
            let checks = try await RecoveryInspector().check(history)
            guard recoveryCheckID == token else { return }
            recoveryChecks = checks
        } catch is CancellationError {
        } catch { if recoveryCheckID == token { self.error = describe(error) } }
    }
    private func preservesDuplicateCopy(_ records: [FileRecord]) -> Bool {
        let paths = Set(records.map(\.path))
        return !duplicates.contains { $0.totalCopies == $0.files.count && $0.files.count > 1 && $0.files.allSatisfy { paths.contains($0.path) } }
    }
    func isCurrentReview(_ review: CleanupReview) -> Bool {
        cleanupReview?.id == review.id && review.canConfirm && review.records == queue && preservesDuplicateCopy(review.records)
    }
    @discardableResult
    func performCleanup(confirmed review: CleanupReview) -> Task<Void, Never>? {
        guard !scanning, !working, !duplicateWorking, let cleanup else { return nil }
        guard isCurrentReview(review) else { self.error = text("error.changed"); return nil }
        let approved = review.records
        cleanupReview = nil
        let cancellation = CleanupCancellation(); cleanupCancellation = cancellation
        working = true; cleaning = true; cleanupCancellationRequested = false
        cleanupProgress = CleanupProgress(total: approved.count)
        return Task {
            defer { working = false; cleaning = false; cleanupCancellation = nil }
            do {
                let results = try await cleanup.clean(confirmed: approved, cancellation: cancellation) { [weak self] state in
                    await MainActor.run { self?.cleanupProgress = state }
                }
                let cancelled = Set(results.filter { $0.status == "cancelled" }.map { $0.record.path })
                queue.removeAll { !cancelled.contains($0.path) }
                try await loadPersistent(); section = "recovery"
            }
            catch { self.error = describe(error); try? await loadPersistent() }
        }
    }
    func cancelCleanup() {
        guard cleaning, !cleanupCancellationRequested else { return }
        cleanupCancellationRequested = true
        cleanupCancellation?.cancel()
    }
    func restore(_ entry: HistoryEntry) {
        guard !working, let cleanup else { return }
        working = true
        Task {
            defer { working = false }
            do { _ = try await cleanup.restore(entry); try await loadPersistent() }
            catch { self.error = describe(error); try? await loadPersistent() }
        }
    }
    func findDuplicates() {
        guard !scanning, !working, !duplicateWorking, let catalog else { return }
        duplicateWorking = true; duplicateCount = 0; duplicateIssues = []; duplicateSkipped = 0
        duplicateTask = Task {
            defer { duplicateWorking = false }
            do {
                let report = try await DuplicateDetector().analyze(catalog: catalog, status: { [weak self] state in
                    await MainActor.run { self?.duplicateAnalysis = state }
                }) { [weak self] count in await MainActor.run { self?.duplicateCount = count } }
                duplicates = report.groups; duplicateTotalGroups = report.totalGroups; duplicateGroupPage = 0; duplicateMemberPages = [:]; duplicateResumeAvailable = false; duplicateIssues = report.issues; duplicateSkipped = report.skippedCount
            }
            catch is CancellationError { duplicateResumeAvailable = (try? await catalog.canResumeDuplicates()) ?? false } catch { self.error = describe(error) }
        }
    }
    func changeDuplicateGroups(by delta: Int) {
        guard !duplicateWorking, !working, let catalog else { return }
        let page = max(0, duplicateGroupPage + delta)
        Task { do {
            let groups = try await catalog.duplicateGroups(offset: page * 200)
            duplicates = groups; duplicateGroupPage = page; duplicateMemberPages = [:]
        } catch { self.error = describe(error) } }
    }
    func changeDuplicateMembers(_ group: DuplicateGroup, by delta: Int) {
        guard !duplicateWorking, !working, let catalog else { return }
        let page = max(0, (duplicateMemberPages[group.id] ?? 0) + delta)
        Task { do {
            let files = try await catalog.duplicateMembers(id: group.id, offset: page * 100)
            if let index = duplicates.firstIndex(where: { $0.id == group.id }) {
                duplicates[index] = DuplicateGroup(id: group.id, files: files, totalCopies: group.totalCopies)
                duplicateMemberPages[group.id] = page
            }
        } catch { self.error = describe(error) } }
    }
    func cancelDuplicates() { duplicateTask?.cancel() }
    func refreshApplications() async {
        guard !loadingApplications, let catalog else {return}
        loadingApplications=true;defer{loadingApplications=false}
        do {applications=try await ApplicationInventory().discover(catalog:catalog,roots:uiFixture.map{[$0.appendingPathComponent("Applications")]},home:uiFixture ?? FileManager.default.homeDirectoryForCurrentUser)} catch {self.error=describe(error)}
    }
    func openStorageLocation(_ url:URL,destination:String="explorer") {
        if let root, FileLocation.contains(url.path,within:root.path) {navigate(url.path)}
        else {scan(url,destination:destination)}
    }
    func refreshDeveloperStorage() async {
        guard !loadingDeveloper, let catalog else {return}
        loadingDeveloper=true;defer{loadingDeveloper=false}
        do {developerEntries=try await DeveloperAnalyzer().discover(catalog:catalog,home:uiFixture ?? FileManager.default.homeDirectoryForCurrentUser,includeSystemLocations:!isUITesting)} catch {self.error=describe(error)}
    }
    func openDeveloperLocation(_ entry: DeveloperStorageEntry) {
        if let root, FileLocation.contains(entry.url.path,within:root.path), entry.logicalSize != nil {navigate(entry.url.path)}
        else {scan(entry.url,destination:"developer")}
    }
    func reveal(_ file: FileRecord) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)]) }
    var locations: [(String, String, URL)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let names = [("applications", "/Applications"), ("documents", "Documents"), ("downloads", "Downloads"), ("desktop", "Desktop"), ("pictures", "Pictures"), ("movies", "Movies"), ("music", "Music"), ("library", "Library")]
        return names.compactMap { key, path in
            let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : home.appendingPathComponent(path)
            return FileManager.default.isReadableFile(atPath: url.path) ? (key, key == "applications" ? "app" : "folder", url) : nil
        }
    }
    var volumes: [URL] { mountedVolumes.map(\.url) }
}

/// Native UI acceptance never moves real files, even when a test accidentally presses Clean.
private struct UITestReadOnlyOperations:TrashOperations {
    func trash(_ url:URL)throws->URL {throw StorageError.refused("error.protected")}
    func restore(_ source:URL,to destination:URL)throws {throw StorageError.refused("error.protected")}
}
