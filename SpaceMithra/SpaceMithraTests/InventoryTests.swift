import Foundation
import XCTest
@testable import SpaceMithraCore

final class InventoryTests:XCTestCase {
    func testRecognizedNodePythonAndOtherLocationsOnlyWhenPresent() async throws {
        let f=try Fixture();defer{f.cleanup()}
        let home=f.root.appendingPathComponent("home",isDirectory:true)
        _=try f.file("home/.npm/_cacache/a",content:"npm")
        _=try f.file("home/.cache/uv/a",content:"uv")
        _=try f.file("home/Library/Caches/pip/a",content:"pip")
        _=try f.file("home/.m2/repository/a",content:"maven")
        _=try f.file("home/project/package.json",content:"{}")
        _=try f.file("home/project/node_modules/example/index.js")
        _=try f.file("home/python/.venv/pyvenv.cfg",content:"home = fixture")
        _=try f.file("home/python/.venv/lib/a.py")
        _=try f.file("home/random/build/personal.txt")
        _=try await StorageScanner().scan(root:home,catalog:f.catalog){_ in}
        let entries=try await DeveloperAnalyzer().discover(catalog:f.catalog,home:home,includeSystemLocations:false)
        XCTAssertTrue(entries.contains{$0.tool == "Node.js / npm" && $0.kind == .cache})
        XCTAssertTrue(entries.contains{$0.tool == "Python / uv" && $0.kind == .cache})
        XCTAssertTrue(entries.contains{$0.tool == "Python / pip" && $0.kind == .cache})
        XCTAssertTrue(entries.contains{$0.tool == "Maven" && $0.kind == .dependencyStore})
        XCTAssertTrue(entries.contains{$0.url.lastPathComponent == "node_modules" && $0.kind == .dependencyStore})
        XCTAssertTrue(entries.contains{$0.url.lastPathComponent == ".venv" && $0.kind == .environment})
        XCTAssertFalse(entries.contains{$0.tool == "Docker"})
        XCTAssertFalse(entries.contains{$0.url.path.contains("/random/build")})
        XCTAssertTrue(entries.allSatisfy{$0.logicalSize != nil})
    }
    func testSourceExtensionsAloneAreNotDisposableDeveloperStorage() throws {
        XCTAssertEqual(Classifier.category(URL(fileURLWithPath:"/Users/example/Documents/lesson.py"),cloud:false),.unknown)
        XCTAssertEqual(Classifier.category(URL(fileURLWithPath:"/Users/example/Documents/website.js"),cloud:false),.unknown)
        let f=try Fixture();defer{f.cleanup()}
        var file=try FileMetadata.read(f.file("source.txt"))
        file.path=f.root.appendingPathComponent("project/node_modules/example/index.js").path
        XCTAssertFalse(RiskEngine.assess(file,protections:[]).eligible)
        file.path=f.root.appendingPathComponent("project/.venv/lib/file.py").path
        XCTAssertFalse(RiskEngine.assess(file,protections:[]).eligible)
    }
    func testApplicationInventorySeparatesBundleCacheAndAttributedData() async throws {
        let f=try Fixture();defer{f.cleanup()}
        let home=f.root.appendingPathComponent("home",isDirectory:true)
        _=try f.file("home/Applications/Fixture.app/Contents/Info.plist",content:"""
        <?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>org.spacemithra.fixture</string>
        <key>CFBundleDisplayName</key><string>Fixture App</string>
        <key>CFBundlePackageType</key><string>APPL</string></dict></plist>
        """)
        _=try f.file("home/Applications/Fixture.app/Contents/Resources/payload",content:"application")
        _=try f.file("home/Library/Caches/org.spacemithra.fixture/a",content:"12345")
        _=try f.file("home/Library/Application Support/org.spacemithra.fixture/a",content:"1234567")
        _=try f.file("home/Library/Application Support/Fixture App/unproven",content:"must not attribute by name")
        _=try await StorageScanner().scan(root:home,catalog:f.catalog){_ in}
        let apps=try await ApplicationInventory().discover(catalog:f.catalog,roots:[home.appendingPathComponent("Applications")],home:home)
        let app=try XCTUnwrap(apps.first)
        XCTAssertEqual(apps.count,1);XCTAssertEqual(app.name,"Fixture App")
        XCTAssertEqual(app.cacheSize,5);XCTAssertEqual(app.relatedDataSize,7)
        XCTAssertGreaterThan(app.bundleSize ?? 0,11)
        XCTAssertEqual(app.relatedDataURLs.count,1)
        if let reportedDate=app.lastUsed {XCTAssertLessThanOrEqual(reportedDate,Date())}
        let bundle=try await f.catalog.record(at:app.url.path)
        XCTAssertEqual(app.bundleSize,bundle?.logical)
    }
}


extension InventoryTests {
    func testApplicationAliasShowsOneOverviewWithoutScanningItsTarget() async throws {
        let f=try Fixture();defer{f.cleanup()}
        let home=f.root.appendingPathComponent("home",isDirectory:true)
        _=try f.file("home/Actual.app/Contents/Info.plist",content:"""
        <?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>org.spacemithra.alias</string><key>CFBundleDisplayName</key><string>Alias Fixture</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
        """)
        let apps=home.appendingPathComponent("Applications",isDirectory:true)
        try FileManager.default.createDirectory(at:apps,withIntermediateDirectories:true)
        try FileManager.default.createSymbolicLink(at:apps.appendingPathComponent("Alias.app"),withDestinationURL:home.appendingPathComponent("Actual.app"))
        let inventory=try await ApplicationInventory().discover(catalog:f.catalog,roots:[apps],home:home)
        XCTAssertEqual(inventory.count,1);XCTAssertEqual(inventory.first?.name,"Alias Fixture")
        XCTAssertNil(inventory.first?.bundleSize)
        let history=try await f.catalog.history();XCTAssertTrue(history.isEmpty)
    }
}
