import XCTest
import Darwin
@testable import SpaceMithraCore

private struct Fixture {
    let root: URL
    let catalog: Catalog
    init() throws {
        // All mutating tests require this explicit flag and a repository-local fixture root.
        guard ProcessInfo.processInfo.environment["SPACEMITHRA_TEST_MODE"] == "1" else {
            throw XCTSkip("Set SPACEMITHRA_TEST_MODE=1 to enable isolated filesystem fixtures")
        }
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        root = repository.appendingPathComponent(".test-fixtures/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        catalog = try Catalog(url: root.appendingPathComponent("catalog/db.sqlite"))
    }
    func file(_ name: String, content: String = "fixture data") throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
        return url
    }
    func cleanup() { try? FileManager.default.removeItem(at: root) }
}
private struct FixtureTrash: TrashOperations {
    let root: URL
    var fail = false
    func trash(_ url: URL) throws -> URL {
        guard url.path.hasPrefix(root.path + "/"), root.path.contains("/.test-fixtures/"), !fail else { throw StorageError.refused("Fixture Trash failure") }
        let trash = root.appendingPathComponent("fixture-trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let destination = trash.appendingPathComponent(UUID().uuidString)
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }
    func restore(_ source: URL, to destination: URL) throws {
        guard source.path.hasPrefix(root.path + "/"), destination.path.hasPrefix(root.path + "/") else { throw StorageError.refused("Outside fixture") }
        try FileManager.default.moveItem(at: source, to: destination)
    }
}
final class CoreTests: XCTestCase {
    func testRecursiveScanAndSymlinkCycle() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let scanned = f.root.appendingPathComponent("scan")
        _ = try f.file("scan/a/b.txt", content: "12345")
        try FileManager.default.createSymbolicLink(at: scanned.appendingPathComponent("a/cycle"), withDestinationURL: scanned)
        let p = try await StorageScanner().scan(root: scanned, catalog: f.catalog) { _ in }
        XCTAssertEqual(p.state, .completed)
        XCTAssertEqual(p.count, 3)
        let children = try await f.catalog.list(parent: scanned.path)
        XCTAssertEqual(children.first?.logical, 5 + (try FileMetadata.read(scanned.appendingPathComponent("a/cycle"))).logical)
        let links = try await f.catalog.list(search: "cycle")
        XCTAssertTrue(links.first?.isSymlink == true)
    }
    func testDirectorySizesAndPaging() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        _ = try f.file("scan/sub/a", content: "123")
        _ = try f.file("scan/sub/b", content: "1234567")
        _ = try await StorageScanner().scan(root: f.root.appendingPathComponent("scan"), catalog: f.catalog) { _ in }
        let directories = try await f.catalog.list(parent: f.root.appendingPathComponent("scan").path)
        XCTAssertEqual(directories.first?.logical, 10)
        let first = try await f.catalog.list(biggest: true, limit: 1)
        let second = try await f.catalog.list(biggest: true, offset: 1, limit: 1)
        XCTAssertEqual(first.first?.logical, 7); XCTAssertEqual(second.first?.logical, 3)
    }
    func testUnknownNeverLowAndNoImplicitSelection() throws {
        let f = try Fixture(); defer { f.cleanup() }
        let record = try FileMetadata.read(f.file("unknown.blob"))
        XCTAssertNotEqual(RiskEngine.assess(record, protections: []).risk, .low)
        XCTAssertEqual(Classifier.category(URL(fileURLWithPath: "/example/mystery"), cloud: false), .unknown)
    }
    func testProtectionUsesPathBoundariesAndExpiry() throws {
        let rule = Protection(path: "/example/a", descendants: true)
        XCTAssertTrue(rule.matches("/example/a/b"))
        XCTAssertFalse(rule.matches("/example/another/b"))
        XCTAssertFalse(Protection(path: "/example/a", descendants: true, expires: .distantPast).matches("/example/a"))
    }
    func testProtectedCleanupRejection() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let record = try FileMetadata.read(f.file("keep.txt"))
        try await f.catalog.saveProtection(Protection(path: record.path, descendants: false))
        let results = try await CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root)).clean(confirmed: [record])
        XCTAssertEqual(results.first?.status, "skipped")
        XCTAssertTrue(FileManager.default.fileExists(atPath: record.path))
    }
    func testChangedFileSkipped() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let url = try f.file("change.txt")
        let record = try FileMetadata.read(url)
        try Data("changed data".utf8).write(to: url)
        let results = try await CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root)).clean(confirmed: [record])
        XCTAssertEqual(results.first?.status, "skipped")
        XCTAssertTrue(FileManager.default.fileExists(atPath: record.path))
    }
    func testTrashAndRestoreConflictThenSuccess() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let url = try f.file("restore.txt")
        let record = try FileMetadata.read(url)
        let engine = CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root))
        let result = try await engine.clean(confirmed: [record])
        let entry = try XCTUnwrap(result.first)
        XCTAssertEqual(entry.status, "trashed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        _ = try f.file("restore.txt", content: "conflict")
        do { _ = try await engine.restore(entry); XCTFail("Must refuse overwrite") } catch {}
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "conflict")
        try FileManager.default.removeItem(at: url)
        let restored = try await engine.restore(entry)
        XCTAssertEqual(restored.status, "restored")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "fixture data")
    }
    func testTrashFailureAndEmptyConfirmation() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let record = try FileMetadata.read(f.file("fail.txt"))
        let engine = CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root, fail: true))
        let empty = try await engine.clean(confirmed: [])
        XCTAssertTrue(empty.isEmpty)
        let result = try await engine.clean(confirmed: [record])
        XCTAssertNotEqual(result.first?.status, "trashed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: record.path))
    }
    func testPartialCleanup() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a")), b = try FileMetadata.read(f.file("b"))
        try await f.catalog.saveProtection(Protection(path: b.path, descendants: false))
        let result = try await CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root)).clean(confirmed: [a,b])
        XCTAssertEqual(result.map(\.status), ["trashed", "skipped"])
        let history = try await f.catalog.history()
        XCTAssertEqual(history.count, 2)
    }
    func testSymlinkParentSwapRejected() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let record = try FileMetadata.read(f.file("original/a.txt"))
        try FileManager.default.moveItem(at: f.root.appendingPathComponent("original"), to: f.root.appendingPathComponent("moved"))
        try FileManager.default.createSymbolicLink(at: f.root.appendingPathComponent("original"), withDestinationURL: f.root.appendingPathComponent("moved"))
        let result = try await CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root)).clean(confirmed: [record])
        XCTAssertEqual(result.first?.status, "skipped")
        XCTAssertTrue(FileManager.default.fileExists(atPath: record.path))
    }
    func testPackageAndHardLinkProtected() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let original = try f.file("scan/a")
        try FileManager.default.linkItem(at: original, to: f.root.appendingPathComponent("scan/b"))
        let record = try FileMetadata.read(original)
        XCTAssertEqual(record.identity.links, 2)
        XCTAssertFalse(RiskEngine.assess(record, protections: []).eligible)
        var packaged = record; packaged.identity.links = 1; packaged.inPackage = true
        XCTAssertFalse(RiskEngine.assess(packaged, protections: []).eligible)
    }
    func testDuplicateHashing() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        _ = try f.file("scan/a.txt", content: "identical")
        _ = try f.file("scan/b.txt", content: "identical")
        _ = try f.file("scan/c.txt", content: "different")
        _ = try await StorageScanner().scan(root: f.root.appendingPathComponent("scan"), catalog: f.catalog) { _ in }
        let groups = try await DuplicateDetector().find(catalog: f.catalog) { _ in }
        XCTAssertEqual(groups.count, 1); XCTAssertEqual(groups.first?.files.count, 2)
    }
    func testCancellation() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        for i in 0..<1000 { _ = try f.file("scan/\(i)") }
        let scanner = StorageScanner()
        let result = try await scanner.scan(root: f.root.appendingPathComponent("scan"), catalog: f.catalog) { p in
            if p.count > 0 { await scanner.cancel() }
        }
        XCTAssertEqual(result.state, .cancelled)
        XCTAssertLessThan(result.count, 1000)
    }
    func testCorruptDatabaseFailsClosed() throws {
        let f = try Fixture(); defer { f.cleanup() }
        let url = try f.file("corrupt.sqlite", content: "not a SQLite database")
        XCTAssertThrowsError(try Catalog(url: url))
    }
    func testUnreadableDirectoryIsReported() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let url = try f.file("scan/denied/a").deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path) }
        let result = try await StorageScanner().scan(root: f.root.appendingPathComponent("scan"), catalog: f.catalog) { _ in }
        XCTAssertEqual(result.state, .completed)
        XCTAssertGreaterThan(result.errors, 0)
    }
    func testLargeDirectoryBenchmark() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        for i in 0..<3000 { _ = try f.file("scan/\(i).txt", content: "1234567890") }
        let start = Date()
        let result = try await StorageScanner().scan(root: f.root.appendingPathComponent("scan"), catalog: f.catalog) { _ in }
        XCTAssertEqual(result.count, 3000); XCTAssertEqual(result.bytes, 30000)
        print("BENCHMARK: 3000 files, \(Date().timeIntervalSince(start)) seconds")
    }
}

extension CoreTests {
    func testHardLinkAggregateCountsOnceAndPreservesDetails() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try f.file("scan/a", content: "1234567890")
        try FileManager.default.linkItem(at: a, to: f.root.appendingPathComponent("scan/b"))
        let result = try await StorageScanner().scan(root: f.root.appendingPathComponent("scan"), catalog: f.catalog) { _ in }
        XCTAssertEqual(result.bytes, 10)
        let files = try await f.catalog.list(biggest: true)
        XCTAssertEqual(files.map(\.logical), [10,10])
    }
    func testScanStartingInsidePackageStillProtectsContents() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        _ = try f.file("Sample.app/Contents/a.txt")
        let root = f.root.appendingPathComponent("Sample.app/Contents")
        _ = try await StorageScanner().scan(root: root, catalog: f.catalog) { _ in }
        let records = try await f.catalog.list(parent: root.path)
        let file = try XCTUnwrap(records.first)
        XCTAssertTrue(file.inPackage)
        XCTAssertFalse(RiskEngine.assess(file, protections: []).eligible)
        let result = try await CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root)).clean(confirmed: [file])
        XCTAssertEqual(result.first?.status, "skipped")
    }
    func testTamperedTrashIsNotRestored() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let file = try FileMetadata.read(f.file("a.txt"))
        let engine = CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root))
        let records = try await engine.clean(confirmed: [file])
        let entry = try XCTUnwrap(records.first)
        let trash = try XCTUnwrap(entry.trashPath)
        try Data("tampered".utf8).write(to: URL(fileURLWithPath: trash))
        do { _ = try await engine.restore(entry); XCTFail("Changed Trash identity must be rejected") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
    func testPersistentProtectionsHistoryAndTrends() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        try await f.catalog.saveProtection(Protection(path: f.root.path, descendants: true))
        try await f.catalog.recordTrend(bytes: 123)
        let reopened = try Catalog(url: f.root.appendingPathComponent("catalog/db.sqlite"))
        let rules = try await reopened.protections(), trends = try await reopened.trends()
        XCTAssertEqual(rules.count, 1); XCTAssertEqual(trends.count, 1); XCTAssertEqual(trends.first?.1, 123)
    }
    func testDateSortingAndLiteralSearch() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try f.file("scan/100%.txt"), b = try f.file("scan/normal.txt")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: a.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: b.path)
        _ = try await StorageScanner().scan(root: f.root.appendingPathComponent("scan"), catalog: f.catalog) { _ in }
        let sorted = try await f.catalog.list(biggest: true, sort: "date")
        XCTAssertEqual(sorted.first?.name, "normal.txt")
        let literal = try await f.catalog.list(search: "%")
        XCTAssertEqual(literal.count, 1)
    }
}

@testable import SpaceMithraPresentation

@MainActor final class PresentationTests: XCTestCase {
    func testQueueKeepsOneDuplicateAcrossAllEntryPoints() throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt"))
        let model = AppModel()
        model.progress.state = .completed
        model.duplicates = [DuplicateGroup(id: "same-hash", files: [a,b])]
        model.enqueue(a); model.enqueue(b)
        XCTAssertEqual(model.queue.map(\.path), [a.path])
        model.keep(a); model.enqueue(b)
        XCTAssertEqual(model.queue.map(\.path), [b.path])
    }
    func testNoSelectionDuringScanAndProtectionWins() throws {
        let f = try Fixture(); defer { f.cleanup() }
        let file = try FileMetadata.read(f.file("keep.txt"))
        let model = AppModel()
        model.progress.state = .scanning
        model.enqueue(file); XCTAssertTrue(model.queue.isEmpty)
        model.progress.state = .completed
        model.protections = [Protection(path: file.path, descendants: false)]
        model.enqueue(file); XCTAssertTrue(model.queue.isEmpty)
        model.protections = []
        model.enqueue(file); XCTAssertEqual(model.queue.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        model.keep(file); XCTAssertTrue(model.queue.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }
    func testCatalogQueriesAndFolderColumnsStayBounded() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        for i in 0..<320 { _ = try f.file("scan/\(i).txt") }
        let root = f.root.appendingPathComponent("scan")
        _ = try await StorageScanner().scan(root: root, catalog: f.catalog) { _ in }
        let model = AppModel(); model.catalog = f.catalog; model.root = root; model.folder = root.path; model.section = "explorer"
        await model.refresh()
        XCTAssertEqual(model.rows.count, 300); XCTAssertTrue(model.hasMore)
        model.page = 1; await model.refresh()
        XCTAssertEqual(model.rows.count, 20); XCTAssertFalse(model.hasMore)
    }
}

extension CoreTests {
    func testIncrementalRescanReusesMetadataAndRemovesDeletedRecords() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        _ = try f.file("scan/a.txt")
        let removed = try f.file("scan/b.txt")
        let root = f.root.appendingPathComponent("scan")
        let scanner = StorageScanner()
        _ = try await scanner.scan(root: root, catalog: f.catalog) { _ in }
        try FileManager.default.removeItem(at: removed)
        _ = try f.file("scan/c.txt", content: "new")
        let result = try await scanner.scan(root: root, catalog: f.catalog) { _ in }
        XCTAssertEqual(result.state, .completed); XCTAssertGreaterThanOrEqual(result.reused, 1)
        let files = try await f.catalog.list(biggest: true, sort: "name")
        XCTAssertEqual(files.map(\.name), ["a.txt", "c.txt"])
    }
}

extension PresentationTests {
    func testLocalizationFallbackUsesEnglishForMissingKeysAndLocales() throws {
        let f = try Fixture(); defer { f.cleanup() }
        _ = try f.file("Fixture.bundle/Contents/Info.plist", content: """
        <?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>org.spacemithra.localization-fixture</string>
        <key>CFBundleDevelopmentRegion</key><string>en</string>
        <key>CFBundlePackageType</key><string>BNDL</string></dict></plist>
        """)
        _ = try f.file("Fixture.bundle/Contents/Resources/en.lproj/Localizable.strings", content: "\"fallback\" = \"English fallback\"; \"title\" = \"Title\";")
        _ = try f.file("Fixture.bundle/Contents/Resources/si.lproj/Localizable.strings", content: "\"title\" = \"මාතෘකාව\";")
        let bundle = try XCTUnwrap(Bundle(url: f.root.appendingPathComponent("Fixture.bundle")))
        XCTAssertEqual(AppModel.localized("title", language: "si", bundle: bundle), "මාතෘකාව")
        XCTAssertEqual(AppModel.localized("fallback", language: "si", bundle: bundle), "English fallback")
        XCTAssertEqual(AppModel.localized("fallback", language: "missing-locale", bundle: bundle), "English fallback")
    }
}

extension CoreTests {
    func testUnrecognizedLibraryStateIsProtectedEvenWithoutDatabaseExtension() throws {
        let f = try Fixture(); defer { f.cleanup() }
        var record = try FileMetadata.read(f.file("ordinary.data"))
        record.path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/example.plist").path
        record.category = .unknown
        XCTAssertFalse(RiskEngine.assess(record, protections: []).eligible)
        record.path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/UnrecognizedVendor/state.bin").path
        XCTAssertFalse(RiskEngine.assess(record, protections: []).eligible)
    }
}

extension PresentationTests {
    func testNonFiniteMinimumSizeInputDoesNotCrash() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let file = try FileMetadata.read(f.file("a.txt"))
        try await f.catalog.insert([file])
        let model = AppModel(); model.catalog = f.catalog; model.section = "biggest"
        model.minimumMB = "1e9999"
        await model.refresh()
        XCTAssertEqual(model.rows.count, 1)
        model.minimumMB = "-100"
        await model.refresh()
        XCTAssertEqual(model.rows.count, 1)
        model.minimumMB = "1e308"
        await model.refresh()
        XCTAssertTrue(model.rows.isEmpty)
    }
}

/// Injection stays in the test target and only mutates its explicitly isolated fixture.
private actor FaultJournal: CleanupJournal {
    enum Fault: Sendable { case pendingWrite, resultWrite, restoreWrite, replaceTrash, createConflict, cancelledWrite }
    let catalog: Catalog
    let root: URL
    let fault: Fault
    init(_ fixture: Fixture, fault: Fault) { catalog = fixture.catalog; root = fixture.root; self.fault = fault }
    func protections() async throws -> [Protection] { try await catalog.protections() }
    func history() async throws -> [HistoryEntry] { try await catalog.history() }
    func saveHistory(_ entry: HistoryEntry) async throws {
        guard root.path.contains("/.test-fixtures/"), entry.record.path.hasPrefix(root.path + "/") else { throw StorageError.refused("Outside fixture") }
        switch (fault, entry.status) {
        case (.pendingWrite, "pending"), (.resultWrite, "trashed"), (.restoreWrite, "restoring"), (.cancelledWrite, "cancelled"):
            throw StorageError.database("Injected journal failure")
        default: break
        }
        try await catalog.saveHistory(entry)
        if entry.status == "restoring" {
            switch fault {
            case .replaceTrash:
                guard let path = entry.trashPath, path.hasPrefix(root.path + "/") else { throw StorageError.refused("Outside fixture") }
                try Data("replacement must stay in fixture Trash".utf8).write(to: URL(fileURLWithPath: path))
            case .createConflict:
                try Data("new original must survive".utf8).write(to: URL(fileURLWithPath: entry.record.path))
            default: break
            }
        }
    }
}

extension CoreTests {
    func testFailedPendingJournalPreventsAnyMove() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt"))
        let engine = CleanupEngine(catalog: FaultJournal(f, fault: .pendingWrite), operations: FixtureTrash(root: f.root))
        do { _ = try await engine.clean(confirmed: [a,b]); XCTFail("Journal failure must abort cleanup") } catch {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: b.path))
        let history = try await f.catalog.history()
        XCTAssertTrue(history.isEmpty)
    }
    func testFailedResultJournalStopsBatchAndLeavesPendingRecovery() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt"))
        let engine = CleanupEngine(catalog: FaultJournal(f, fault: .resultWrite), operations: FixtureTrash(root: f.root))
        do { _ = try await engine.clean(confirmed: [a,b]); XCTFail("Final journal failure must stop the batch") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: b.path))
        let history = try await f.catalog.history()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.status, "pending")
        XCTAssertNil(history.first?.trashPath)
        // The physical file remains available for manual inspection; no false success persisted.
        let trash = try FileManager.default.contentsOfDirectory(at: f.root.appendingPathComponent("fixture-trash"), includingPropertiesForKeys: nil)
        XCTAssertEqual(trash.count, 1)
    }
    func testFailedRestoreJournalPreventsMove() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let file = try FileMetadata.read(f.file("a.txt"))
        let results = try await CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root)).clean(confirmed: [file])
        let entry = try XCTUnwrap(results.first)
        let engine = CleanupEngine(catalog: FaultJournal(f, fault: .restoreWrite), operations: FixtureTrash(root: f.root))
        do { _ = try await engine.restore(entry); XCTFail("Restore requires a successful journal write") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(entry.trashPath)))
        let history = try await f.catalog.history()
        XCTAssertEqual(history.first?.status, "trashed")
    }
    func testTrashChangedDuringRestoreJournalIsNotMoved() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let file = try FileMetadata.read(f.file("a.txt"))
        let results = try await CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root)).clean(confirmed: [file])
        let entry = try XCTUnwrap(results.first)
        let engine = CleanupEngine(catalog: FaultJournal(f, fault: .replaceTrash), operations: FixtureTrash(root: f.root))
        do { _ = try await engine.restore(entry); XCTFail("Changed Trash item must remain untouched") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let trash = URL(fileURLWithPath: try XCTUnwrap(entry.trashPath))
        XCTAssertEqual(try String(contentsOf: trash, encoding: .utf8), "replacement must stay in fixture Trash")
        let history = try await f.catalog.history()
        XCTAssertEqual(history.first?.status, "restoring")
    }
    func testOriginalCreatedDuringRestoreJournalIsNotOverwritten() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let file = try FileMetadata.read(f.file("a.txt"))
        let results = try await CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root)).clean(confirmed: [file])
        let entry = try XCTUnwrap(results.first)
        let engine = CleanupEngine(catalog: FaultJournal(f, fault: .createConflict), operations: FixtureTrash(root: f.root))
        do { _ = try await engine.restore(entry); XCTFail("New original must not be overwritten") } catch {}
        XCTAssertEqual(try String(contentsOfFile: file.path, encoding: .utf8), "new original must survive")
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(entry.trashPath)))
    }
}

extension CoreTests {
    func testReviewIsReadOnlyAndEmptySelectionCannotConfirm() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let record = try FileMetadata.read(f.file("a.txt"))
        let reviewer = CleanupReviewer()
        let empty = try await reviewer.review([], journal: f.catalog)
        XCTAssertFalse(empty.canConfirm)
        let review = try await reviewer.review([record], journal: f.catalog)
        XCTAssertTrue(review.canConfirm); XCTAssertEqual(review.readyCount, 1)
        XCTAssertEqual(review.records, [record])
        XCTAssertEqual(try FileMetadata.identity(record.path), record.identity)
        let history = try await f.catalog.history()
        XCTAssertTrue(history.isEmpty)
    }
    func testReviewRejectsChangedAndNewlyProtectedFilesWithoutRefreshingApproval() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt"))
        try Data("changed".utf8).write(to: URL(fileURLWithPath: a.path))
        try await f.catalog.saveProtection(Protection(path: b.path, descendants: false))
        let review = try await CleanupReviewer().review([a,b], journal: f.catalog)
        XCTAssertFalse(review.canConfirm); XCTAssertEqual(review.blockedCount, 2)
        XCTAssertEqual(review.records, [a,b])
        XCTAssertEqual(review.items.first?.blocker, "error.changed")
        XCTAssertEqual(review.items.last?.blocker, "error.protected")
    }
    func testReviewReportsUnwritableParentBeforeConfirmation() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let record = try FileMetadata.read(f.file("readonly/a.txt"))
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: record.parent)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: record.parent) }
        let review = try await CleanupReviewer().review([record], journal: f.catalog)
        XCTAssertFalse(review.canConfirm)
        XCTAssertEqual(review.items.first?.blocker, "error.permission")
        XCTAssertTrue(FileManager.default.fileExists(atPath: record.path))
    }
    func testHistoryGroupsMixedResultsByActualSession() throws {
        let f = try Fixture(); defer { f.cleanup() }
        let record = try FileMetadata.read(f.file("a.txt"))
        let entries = [
            HistoryEntry(id: "1", session: "older", record: record, date: Date(timeIntervalSince1970: 1), status: "trashed", message: "message.trashed"),
            HistoryEntry(id: "2", session: "newer", record: record, date: Date(timeIntervalSince1970: 2), status: "pending", message: "message.pending"),
            HistoryEntry(id: "3", session: "older", record: record, date: Date(timeIntervalSince1970: 1), status: "skipped", message: "error.changed")
        ]
        let sessions = CleanupHistorySession.group(entries)
        XCTAssertEqual(sessions.map(\.id), ["newer", "older"])
        XCTAssertEqual(sessions.last?.counts, ["trashed": 1, "skipped": 1])
        XCTAssertEqual(sessions.last?.estimatedSelectedBytes, record.logical * 2)
        XCTAssertEqual(sessions.first?.counts, ["pending": 1])
    }
}

extension PresentationTests {
    func testChangedQueueAndCancelledReviewInvalidateApproval() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt", content: "a different selected size"))
        let model = AppModel(); model.catalog = f.catalog; model.queue = [a]
        await model.prepareCleanupReview()
        let review = try XCTUnwrap(model.cleanupReview)
        XCTAssertTrue(model.isCurrentReview(review))
        model.queue = [b]
        XCTAssertEqual(review.estimatedSelectedBytes, a.logical)
        XCTAssertNotEqual(review.estimatedSelectedBytes, model.queuedBytes)
        XCTAssertFalse(model.isCurrentReview(review))
        model.queue = [a]
        model.cancelCleanupReview()
        XCTAssertFalse(model.isCurrentReview(review))
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.path))
        let history = try await f.catalog.history()
        XCTAssertTrue(history.isEmpty)
    }
}

private actor ReviewGate: CleanupJournal {
    let catalog: Catalog
    private var entered = false
    private var gate: CheckedContinuation<Void, Never>?
    private var observers: [CheckedContinuation<Void, Never>] = []
    init(catalog: Catalog) { self.catalog = catalog }
    func protections() async throws -> [Protection] {
        let rules = try await catalog.protections()
        await withCheckedContinuation { continuation in
            gate = continuation; entered = true
            observers.forEach { $0.resume() }; observers.removeAll()
        }
        return rules
    }
    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func release() { gate?.resume(); gate = nil }
    func history() async throws -> [HistoryEntry] { try await catalog.history() }
    func saveHistory(_ entry: HistoryEntry) async throws { try await catalog.saveHistory(entry) }
}

extension PresentationTests {
    func testCancellingInFlightReviewCannotReappearAsApproval() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let record = try FileMetadata.read(f.file("a.txt"))
        let gate = ReviewGate(catalog: f.catalog)
        let model = AppModel(); model.catalog = f.catalog; model.queue = [record]
        let task = Task { await model.prepareCleanupReview(using: gate) }
        await gate.waitUntilEntered()
        XCTAssertTrue(model.preparingReview); XCTAssertTrue(model.working)
        model.cancelCleanupReview()
        await gate.release()
        await task.value
        XCTAssertNil(model.cleanupReview); XCTAssertNil(model.error)
        XCTAssertFalse(model.preparingReview); XCTAssertFalse(model.working)
        XCTAssertTrue(FileManager.default.fileExists(atPath: record.path))
        let history = try await f.catalog.history()
        XCTAssertTrue(history.isEmpty)
    }
}

extension CoreTests {
    func testRecoveryAvailabilityTracksPresenceConflictAndMissingTrash() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let record = try FileMetadata.read(f.file("a.txt"))
        let results = try await CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root)).clean(confirmed: [record])
        let entry = try XCTUnwrap(results.first)
        let inspector = RecoveryInspector()
        let available = try await inspector.check([entry])
        XCTAssertEqual(available[entry.id]?.availability, .available)
        _ = try f.file("a.txt", content: "conflicting original")
        let conflict = try await inspector.check([entry])
        XCTAssertEqual(conflict[entry.id]?.availability, .conflict)
        XCTAssertFalse(conflict[entry.id]?.canRestore ?? true)
        try FileManager.default.removeItem(atPath: try XCTUnwrap(entry.trashPath))
        let missing = try await inspector.check([entry])
        XCTAssertEqual(missing[entry.id]?.availability, .missing)
        XCTAssertEqual(try String(contentsOfFile: record.path, encoding: .utf8), "conflicting original")
        let unchangedHistory = try await f.catalog.history()
        XCTAssertEqual(unchangedHistory.first?.status, "trashed")
    }
    func testRecoveryAvailabilityRejectsTamperingAndUncertainHistory() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let record = try FileMetadata.read(f.file("a.txt"))
        let results = try await CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root)).clean(confirmed: [record])
        var entry = try XCTUnwrap(results.first)
        let inspector = RecoveryInspector()
        try Data("changed Trash content".utf8).write(to: URL(fileURLWithPath: try XCTUnwrap(entry.trashPath)))
        let changed = try await inspector.check([entry])
        XCTAssertEqual(changed[entry.id]?.availability, .changed)
        entry.status = "pending"
        let pending = try await inspector.check([entry])
        XCTAssertEqual(pending[entry.id]?.availability, .notApplicable)
        entry.status = "trashed"; entry.trashIdentity = nil
        let unknown = try await inspector.check([entry])
        XCTAssertEqual(unknown[entry.id]?.availability, .unverified)
    }
    func testDuplicateDetectionExcludesCloudCategoryAndUnestablishedFileType() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt"))
        var b = try FileMetadata.read(f.file("b.txt"))
        b.category = .cloud; b.cloud = false
        try await f.catalog.insert([a,b])
        let cloud = try await DuplicateDetector().find(catalog: f.catalog) { _ in }
        XCTAssertTrue(cloud.isEmpty)
        b.category = .unknown; b.isRegular = nil
        try await f.catalog.insert([b])
        let unknownType = try await DuplicateDetector().find(catalog: f.catalog) { _ in }
        XCTAssertTrue(unknownType.isEmpty)
    }
}

extension CoreTests {
    func testDuplicateReportContinuesWhenOneCandidateDisappears() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt")), c = try FileMetadata.read(f.file("c.txt"))
        try await f.catalog.insert([a,b,c])
        try FileManager.default.removeItem(atPath: c.path)
        let report = try await DuplicateDetector().analyze(catalog: f.catalog) { _ in }
        XCTAssertEqual(report.groups.count, 1)
        XCTAssertEqual(report.groups.first?.files.map(\.path), [a.path,b.path])
        XCTAssertEqual(report.skippedCount, 1); XCTAssertEqual(report.issues.first?.path, c.path)
    }
    func testDuplicateReportContinuesPastUnreadableFile() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt"))
        let denied = try f.file("c.txt")
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: denied.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: denied.path) }
        let c = try FileMetadata.read(denied)
        try await f.catalog.insert([a,b,c])
        let report = try await DuplicateDetector().analyze(catalog: f.catalog) { _ in }
        XCTAssertEqual(report.groups.first?.files.count, 2)
        XCTAssertEqual(report.skippedCount, 1)
        XCTAssertEqual(report.issues.first?.path, c.path)
    }
    func testEarlierHashChangedDuringProgressIsRemovedFromResults() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt")), c = try FileMetadata.read(f.file("c.txt"))
        try await f.catalog.insert([a,b,c])
        let path = a.path
        let report = try await DuplicateDetector().analyze(catalog: f.catalog) { checked in
            if checked == 2 { try? Data("changed after hashing".utf8).write(to: URL(fileURLWithPath: path)) }
        }
        XCTAssertEqual(report.groups.first?.files.map(\.path), [b.path,c.path])
        XCTAssertEqual(report.skippedCount, 1); XCTAssertEqual(report.issues.first?.path, a.path)
    }
    func testSecureDescriptorRejectsReplacedLeafAndSymbolicLinkAncestor() throws {
        let f = try Fixture(); defer { f.cleanup() }
        let url = try f.file("original/a.txt")
        let record = try FileMetadata.read(url)
        try FileManager.default.moveItem(at: url, to: f.root.appendingPathComponent("saved.txt"))
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: f.root.appendingPathComponent("saved.txt"))
        XCTAssertThrowsError(try SecureDuplicateHasher().openValidated(record))
        try FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: f.root.appendingPathComponent("saved.txt"), to: url)
        let fresh = try FileMetadata.read(url)
        try FileManager.default.moveItem(at: url.deletingLastPathComponent(), to: f.root.appendingPathComponent("moved"))
        try FileManager.default.createSymbolicLink(at: f.root.appendingPathComponent("original"), withDestinationURL: f.root.appendingPathComponent("moved"))
        XCTAssertThrowsError(try SecureDuplicateHasher().openValidated(fresh))
        XCTAssertEqual(try String(contentsOfFile: f.root.appendingPathComponent("moved/a.txt").path, encoding: .utf8), "fixture data")
    }
    func testDuplicateCancellationDoesNotBecomeSkippedFileResult() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt"))
        try await f.catalog.insert([a,b])
        let catalog = f.catalog
        let task = Task {
            try await DuplicateDetector().analyze(catalog: catalog) { _ in
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        do { _ = try await task.value; XCTFail("Cancellation must abort analysis") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }
}

extension PresentationTests {
    func testKnownDuplicatesAlreadyQueuedCannotAllBeApproved() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt"))
        let model = AppModel(); model.catalog = f.catalog; model.queue = [a,b]
        model.duplicates = [DuplicateGroup(id: "same", files: [a,b])]
        await model.prepareCleanupReview()
        XCTAssertNil(model.cleanupReview); XCTAssertNotNil(model.error)
        model.keep(b)
        await model.prepareCleanupReview()
        XCTAssertTrue(try XCTUnwrap(model.cleanupReview).canConfirm)
    }
    func testAnalysisBlocksSelectionAndGlobalCancelCancelsPreflight() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let file = try FileMetadata.read(f.file("a.txt"))
        let model = AppModel(); model.catalog = f.catalog; model.progress.state = .completed; model.duplicateWorking = true
        model.enqueue(file); XCTAssertTrue(model.queue.isEmpty)
        model.duplicateWorking = false; model.queue = [file]
        let gate = ReviewGate(catalog: f.catalog)
        let task = Task { await model.prepareCleanupReview(using: gate) }
        await gate.waitUntilEntered()
        model.cancel(); await gate.release(); await task.value
        XCTAssertNil(model.cleanupReview); XCTAssertNil(model.error)
        XCTAssertFalse(model.working)
    }
}

extension CoreTests {
    func testDuplicateHashIncludesBytesBeyondOneMegabyte() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let prefix = String(repeating: "a", count: 1024 * 1024)
        let a = try FileMetadata.read(f.file("a.bin", content: prefix + "x"))
        let b = try FileMetadata.read(f.file("b.bin", content: prefix + "x"))
        let c = try FileMetadata.read(f.file("c.bin", content: prefix + "y"))
        try await f.catalog.insert([a,b,c])
        let report = try await DuplicateDetector().analyze(catalog: f.catalog) { _ in }
        XCTAssertEqual(report.groups.count, 1)
        XCTAssertEqual(report.groups.first?.files.map(\.path), [a.path,b.path])
        XCTAssertEqual(report.hashedCount, 3); XCTAssertEqual(report.skippedCount, 0)
    }
    func testSecureDescriptorRejectsFIFOReplacementWithoutWaitingForWriter() throws {
        let f = try Fixture(); defer { f.cleanup() }
        let url = try f.file("replaced.txt")
        let record = try FileMetadata.read(url)
        try FileManager.default.removeItem(at: url)
        XCTAssertEqual(mkfifo(url.path, 0o600), 0)
        // No writer exists: a blocking open would hang. NONBLOCK + fstat must reject it.
        XCTAssertThrowsError(try SecureDuplicateHasher().openValidated(record))
        var info = stat()
        XCTAssertEqual(lstat(url.path, &info), 0)
        XCTAssertEqual(info.st_mode & mode_t(S_IFMT), mode_t(S_IFIFO))
    }
}

extension PresentationTests {
    func testStartingThenCancellingAnalysisDoesNotDiscardKnownDuplicateGroups() throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt"))
        let model = AppModel(); model.catalog = f.catalog
        model.duplicates = [DuplicateGroup(id: "known", files: [a,b])]
        model.findDuplicates()
        XCTAssertTrue(model.duplicateWorking)
        XCTAssertEqual(model.duplicates.map(\.id), ["known"])
        model.cancelDuplicates()
        XCTAssertEqual(model.duplicates.map(\.id), ["known"])
    }
}

private actor CleanupProgressLog {
    private var states: [CleanupProgress] = []
    func append(_ state: CleanupProgress) { states.append(state) }
    func all() -> [CleanupProgress] { states }
}
private actor PendingCleanupGate: CleanupJournal {
    let catalog: Catalog
    private var gate: CheckedContinuation<Void, Never>?
    private var entered = false
    private var observers: [CheckedContinuation<Void, Never>] = []
    init(catalog: Catalog) { self.catalog = catalog }
    func protections() async throws -> [Protection] { try await catalog.protections() }
    func history() async throws -> [HistoryEntry] { try await catalog.history() }
    func saveHistory(_ entry: HistoryEntry) async throws {
        try await catalog.saveHistory(entry)
        if entry.status == "pending" {
            await withCheckedContinuation { continuation in
                gate = continuation; entered = true
                observers.forEach { $0.resume() }; observers.removeAll()
            }
        }
    }
    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func release() { gate?.resume(); gate = nil }
}

extension CoreTests {
    func testCleanupCancellationBeforeFirstItemJournalsUntouchedSelection() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt"))
        let engine = CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root))
        let log = CleanupProgressLog()
        let result = try await engine.clean(confirmed: [a,b]) { state in
            await log.append(state)
            if state.completed == 0 { await engine.requestCancellation() }
        }
        XCTAssertEqual(result.map(\.status), ["cancelled", "cancelled"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.path)); XCTAssertTrue(FileManager.default.fileExists(atPath: b.path))
        let history = try await f.catalog.history(), states = await log.all()
        XCTAssertEqual(history.count, 2); XCTAssertEqual(Set(history.map(\.session)).count, 1)
        XCTAssertEqual(states.map(\.completed), [0,1,2])
        XCTAssertEqual(states.last?.cancelled, 2); XCTAssertEqual(states.last?.moved, 0)
    }
    func testCleanupStopsBetweenJournaledItemsAndFreshBatchCanProceed() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt")), c = try FileMetadata.read(f.file("c.txt"))
        let engine = CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root))
        let result = try await engine.clean(confirmed: [a,b,c]) { state in
            if state.completed == 1 { await engine.requestCancellation() }
        }
        XCTAssertEqual(result.map(\.status), ["trashed", "cancelled", "cancelled"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.path))
        XCTAssertEqual(try FileMetadata.identity(b.path), b.identity)
        XCTAssertEqual(try FileMetadata.identity(c.path), c.identity)
        let retry = try await engine.clean(confirmed: [b,c])
        XCTAssertEqual(retry.map(\.status), ["trashed", "trashed"])
        XCTAssertNotEqual(result.first?.session, retry.first?.session)
    }
    func testCancellationDuringPendingJournalPreventsTrash() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt"))
        let journal = PendingCleanupGate(catalog: f.catalog)
        let engine = CleanupEngine(catalog: journal, operations: FixtureTrash(root: f.root))
        let task = Task { try await engine.clean(confirmed: [a]) }
        await journal.waitUntilEntered()
        await engine.requestCancellation(); await journal.release()
        let result = try await task.value
        XCTAssertEqual(result.first?.status, "cancelled")
        XCTAssertEqual(try FileMetadata.identity(a.path), a.identity)
        let history = try await f.catalog.history()
        XCTAssertEqual(history.first?.status, "cancelled")
        XCTAssertNil(history.first?.trashPath)
    }
    func testCancelledJournalFailureStopsWithoutMovingFiles() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt"))
        let engine = CleanupEngine(catalog: FaultJournal(f, fault: .cancelledWrite), operations: FixtureTrash(root: f.root))
        let token = CleanupCancellation(); token.cancel()
        do { _ = try await engine.clean(confirmed: [a], cancellation: token); XCTFail("Must propagate cancellation journal failure") } catch {}
        XCTAssertEqual(try FileMetadata.identity(a.path), a.identity)
        let history = try await f.catalog.history()
        XCTAssertTrue(history.isEmpty)
    }
}

extension PresentationTests {
    func testImmediateCleanupCancellationRetainsQueueForFreshReview() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt"))
        let engine = CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root))
        let model = AppModel(catalog: f.catalog, cleanup: engine)
        model.queue = [a,b]
        await model.prepareCleanupReview()
        let review = try XCTUnwrap(model.cleanupReview)
        let task = try XCTUnwrap(model.performCleanup(confirmed: review))
        model.cancel()
        await task.value
        XCTAssertEqual(model.queue.map(\.path), [a.path,b.path])
        XCTAssertEqual(model.cleanupProgress.cancelled, 2); XCTAssertEqual(model.cleanupProgress.moved, 0)
        XCTAssertFalse(model.cleaning); XCTAssertFalse(model.working); XCTAssertNil(model.error)
        XCTAssertFalse(model.isCurrentReview(review))
        XCTAssertEqual(model.history.map(\.status), ["cancelled", "cancelled"])
        XCTAssertEqual(try FileMetadata.identity(a.path), a.identity)
    }
    func testAlreadyCancelledCallerCannotMoveApprovedFile() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt"))
        let engine = CleanupEngine(catalog: f.catalog, operations: FixtureTrash(root: f.root))
        let task = Task { try await engine.clean(confirmed: [a]) }
        task.cancel()
        let result = try await task.value
        XCTAssertEqual(result.first?.status, "cancelled")
        XCTAssertEqual(try FileMetadata.identity(a.path), a.identity)
    }
}

private struct CancellingFixtureTrash: TrashOperations {
    let root: URL
    let cancellation: CleanupCancellation
    func trash(_ url: URL) throws -> URL {
        let destination = try FixtureTrash(root: root).trash(url)
        cancellation.cancel()
        return destination
    }
    func restore(_ source: URL, to destination: URL) throws { try FixtureTrash(root: root).restore(source, to: destination) }
}
extension CoreTests {
    func testCancellationDuringMoveStillJournalsSuccessfulCurrentItem() async throws {
        let f = try Fixture(); defer { f.cleanup() }
        let a = try FileMetadata.read(f.file("a.txt")), b = try FileMetadata.read(f.file("b.txt"))
        let token = CleanupCancellation()
        let engine = CleanupEngine(catalog: f.catalog, operations: CancellingFixtureTrash(root: f.root, cancellation: token))
        let results = try await engine.clean(confirmed: [a,b], cancellation: token)
        XCTAssertEqual(results.map(\.status), ["trashed", "cancelled"])
        XCTAssertNotNil(results.first?.trashPath); XCTAssertNotNil(results.first?.trashIdentity)
        XCTAssertEqual(try FileMetadata.identity(b.path), b.identity)
        let history = try await f.catalog.history()
        XCTAssertEqual(history.first(where: { $0.record.path == a.path })?.status, "trashed")
        XCTAssertEqual(history.first(where: { $0.record.path == b.path })?.status, "cancelled")
    }
}
