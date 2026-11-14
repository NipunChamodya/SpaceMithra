import XCTest
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
