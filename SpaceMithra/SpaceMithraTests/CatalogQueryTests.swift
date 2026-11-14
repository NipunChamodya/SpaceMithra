import XCTest
import Foundation
import SQLite3
@testable import SpaceMithraCore
@testable import SpaceMithraPresentation

final class CatalogQueryTests:XCTestCase {
    func testExtensionAndHiddenFiltersApplyBeforePaging() async throws {
        let f=try Fixture();defer{f.cleanup()}
        var records:[FileRecord]=[]
        for i in 0..<320 {records.append(try FileMetadata.read(f.file("scan/.hidden\(i).txt",content:"long hidden file")))}
        records.append(try FileMetadata.read(f.file("scan/visible.pdf",content:"pdf")))
        try await f.catalog.insert(records)
        let visible=try await f.catalog.list(biggest:true,showHidden:false,limit:301)
        XCTAssertEqual(visible.map(\.name),["visible.pdf"])
        let filtered=try await f.catalog.list(biggest:true,extensionFilter:"pdf",limit:1)
        XCTAssertEqual(filtered.first?.name,"visible.pdf")
    }
    func testUnicodeSearchAndModifiedFiltersUseCompleteCatalog() async throws {
        let f=try Fixture();defer{f.cleanup()}
        let a=try f.file("École.txt"),b=try f.file("පින්තූර.txt")
        try FileManager.default.setAttributes([.modificationDate:Date(timeIntervalSince1970:1)],ofItemAtPath:a.path)
        try FileManager.default.setAttributes([.modificationDate:Date(timeIntervalSince1970:100)],ofItemAtPath:b.path)
        try await f.catalog.insert([try FileMetadata.read(a),try FileMetadata.read(b)])
        let french=try await f.catalog.list(search:"e\u{301}COLE")
        XCTAssertEqual(french.first?.path,a.path)
        let sinhala=try await f.catalog.list(search:"පින්තූර")
        XCTAssertEqual(sinhala.first?.path,b.path)
        let newer=try await f.catalog.list(modifiedAfter:Date(timeIntervalSince1970:50))
        XCTAssertEqual(newer.first?.path,b.path)
    }
    func testLegacyCatalogMigrationPreservesRecoveryAndAddsIndexes() async throws {
        let f=try Fixture();defer{f.cleanup()}
        let record=try FileMetadata.read(f.file("École.txt",content:"12345"))
        let directory=f.root.appendingPathComponent("legacy",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let url=directory.appendingPathComponent("db.sqlite")
        var db:OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path,&db),SQLITE_OK);defer{sqlite3_close(db)}
        XCTAssertEqual(sqlite3_exec(db,"CREATE TABLE files(path TEXT PRIMARY KEY,parent TEXT,name TEXT,category TEXT,directory INTEGER,size INTEGER,allocated INTEGER,payload BLOB); CREATE TABLE history(id TEXT PRIMARY KEY,payload BLOB);",nil,nil,nil),SQLITE_OK)
        var insert:OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db,"INSERT INTO files VALUES(?,?,?,?,0,5,5,?)",-1,&insert,nil),SQLITE_OK)
        for(index,value) in [record.path,record.parent,record.name,record.category.rawValue].enumerated(){_=value.withCString{sqlite3_bind_text(insert,Int32(index+1),$0,-1,unsafeBitCast(-1,to:sqlite3_destructor_type.self))}}
        let payload=try JSONEncoder().encode(record)
        _=payload.withUnsafeBytes{sqlite3_bind_blob(insert,5,$0.baseAddress,Int32(payload.count),unsafeBitCast(-1,to:sqlite3_destructor_type.self))}
        XCTAssertEqual(sqlite3_step(insert),SQLITE_DONE);sqlite3_finalize(insert)
        let entry=HistoryEntry(id:"legacy",session:"legacy-session",record:record,date:Date(),status:"pending",message:"message.pending")
        let historyData=try JSONEncoder().encode(entry)
        XCTAssertEqual(sqlite3_prepare_v2(db,"INSERT INTO history VALUES('legacy',?)",-1,&insert,nil),SQLITE_OK)
        _=historyData.withUnsafeBytes{sqlite3_bind_blob(insert,1,$0.baseAddress,Int32(historyData.count),unsafeBitCast(-1,to:sqlite3_destructor_type.self))}
        XCTAssertEqual(sqlite3_step(insert),SQLITE_DONE);sqlite3_finalize(insert)
        let catalog=try Catalog(url:url)
        let matches=try await catalog.list(search:"éCOLE",minimumSize:4)
        XCTAssertEqual(matches.first?.path,record.path)
        let history=try await catalog.history()
        XCTAssertEqual(history.first?.id,"legacy");XCTAssertEqual(history.first?.status,"pending")
    }
    func testCoverageContextPersistsAndBucketTotalsDoNotDoubleCountDownloads() async throws {
        let f=try Fixture();defer{f.cleanup()}
        let home=f.root.appendingPathComponent("home",isDirectory:true)
        _=try f.file("home/Downloads/photo.jpg",content:"123")
        _=try f.file("home/Pictures/photo.jpg",content:"12345")
        _=try await StorageScanner().scan(root:home,catalog:f.catalog){_ in}
        let context=try await f.catalog.scanContext(),buckets=try await f.catalog.dashboardBuckets(home:home)
        XCTAssertEqual(context?.root,home.path);XCTAssertEqual(context?.state,.completed);XCTAssertNotNil(context?.finished)
        XCTAssertEqual(buckets["downloads"],3);XCTAssertEqual(buckets["images"],5)
        XCTAssertEqual(buckets.values.reduce(0,+),8)
    }
    func testDiskEstimateDoesNotInventReconciliationForSharedBlocks() throws {
        let disk=try DiskCapacitySnapshot(name:"fixture",volumeURL:URL(fileURLWithPath:"/"),total:100,available:40)
        XCTAssertEqual(DiskScanAccounting(disk:disk,allocatedKnown:20,sameStartupStorage:true).unattributedUsedEstimate,40)
        XCTAssertNil(DiskScanAccounting(disk:disk,allocatedKnown:80,sameStartupStorage:true).unattributedUsedEstimate)
        XCTAssertEqual(DiskScanAccounting(disk:disk,allocatedKnown:20,sameStartupStorage:false).unattributedUsedEstimate,60)
    }
}

extension CatalogQueryTests {
    @MainActor func testFolderNavigationClearsDashboardCategoryScope() throws {
        let f=try Fixture();defer{f.cleanup()}
        let model=AppModel(catalog:f.catalog)
        model.root=f.root;model.folder=f.root.path;model.overviewBucket="videos";model.category = .videos
        model.analysisPathPrefix="/unrelated";model.search="old search";model.modifiedBefore=Date()
        model.navigate(f.root.path)
        XCTAssertNil(model.overviewBucket);XCTAssertNil(model.category);XCTAssertNil(model.analysisPathPrefix)
        XCTAssertNil(model.modifiedBefore);XCTAssertTrue(model.search.isEmpty)
    }
    func testRootProtectionCoversDescendantsWithoutNameCollisions() throws {
        let f=try Fixture();defer{f.cleanup()}
        let file=try FileMetadata.read(f.file("a"))
        XCTAssertFalse(RiskEngine.assess(file,protections:[Protection(path:"/",descendants:true)]).eligible)
        XCTAssertFalse(Protection(path:f.root.path+"-other",descendants:true).matches(file.path))
    }
    func testRescanHidesStaleDuplicatePagesButKeepsSafetyProofs() async throws {
        let f=try Fixture();defer{f.cleanup()}
        let a=try FileMetadata.read(f.file("a")),b=try FileMetadata.read(f.file("b"))
        try await f.catalog.insert([a,b]);_ = try await DuplicateDetector().analyze(catalog:f.catalog){_ in}
        let groups=try await f.catalog.duplicateGroups();XCTAssertEqual(groups.count,1)
        try await f.catalog.resetScan();let stale=try await f.catalog.duplicateGroups();XCTAssertTrue(stale.isEmpty)
        let keepers=try await f.catalog.duplicateKeepers(for:[a]);XCTAssertEqual(keepers[a.path]?.path,b.path)
    }
}


extension CatalogQueryTests {
    func testLexicalNormalizationPreservesPrivateDirectoryIdentityAndProtectsAliases() throws {
        let location=try FileLocation.fileURL(path:"/private/var/./log/../")
        XCTAssertEqual(location.path,"/private/var")
        let actual=try FileMetadata.read(location)
        XCTAssertTrue(actual.isDirectory);XCTAssertFalse(actual.isSymlink)
        let f=try Fixture();defer{f.cleanup()}
        var file=try FileMetadata.read(f.file("a"))
        for path in ["/private/var/db/example","/var/db/example","/etc/example","/tmp/example"] {
            file.path=path
            XCTAssertFalse(RiskEngine.assess(file,protections:[]).eligible,path)
        }
    }
}
