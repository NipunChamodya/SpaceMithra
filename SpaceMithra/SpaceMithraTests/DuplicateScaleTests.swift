import Foundation
import Darwin
import XCTest
@testable import SpaceMithraCore

private actor StatusRecorder {
    var resumed = false
    func record(_ state: DuplicateAnalysisProgress) { resumed = resumed || state.resumed }
}
private final class CountingReader: DuplicateContentReading, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var fullReads: Int { lock.lock(); defer {lock.unlock()}; return count }
    func sampleDigest(_ file: FileRecord) throws -> String { try SecureDuplicateHasher().sampleDigest(file) }
    func digest(_ file: FileRecord) throws -> String {
        lock.lock(); count += 1; lock.unlock()
        return try SecureDuplicateHasher().digest(file)
    }
}
final class DuplicateScaleTests: XCTestCase {
    func testCancelledAnalysisResumesAndPagesAllCopies() async throws {
        let f=try Fixture(); defer {f.cleanup()}
        var records:[FileRecord]=[]
        for i in 0..<300 { records.append(try FileMetadata.read(f.file("\(i).bin",content:"identical"))) }
        try await f.catalog.insert(records)
        let catalog=f.catalog
        let task=Task { try await DuplicateDetector().analyze(catalog:catalog) { count in
            if count == 130 { withUnsafeCurrentTask { $0?.cancel() } }
        } }
        do { _=try await task.value; XCTFail("Expected cancellation") } catch is CancellationError {}
        let resumable=try await catalog.canResumeDuplicates(); XCTAssertTrue(resumable)
        let recorder=StatusRecorder()
        let report=try await DuplicateDetector().analyze(catalog:catalog,status:{await recorder.record($0)}) {_ in}
        let didResume=await recorder.resumed
        XCTAssertTrue(didResume); XCTAssertEqual(report.candidateCount,300)
        XCTAssertEqual(report.groups.first?.totalCopies,300); XCTAssertEqual(report.groups.first?.files.count,100)
        let id=try XCTUnwrap(report.groups.first?.id)
        let page=try await catalog.duplicateMembers(id:id,offset:200)
        XCTAssertEqual(page.count,100); XCTAssertEqual(Set(page.map(\.path)).count,100)
        let complete=try await catalog.canResumeDuplicates(); XCTAssertFalse(complete)
    }
    func testDiskBackedKeeperConstraintRejectsAllCopiesEvenAfterRescan() async throws {
        let f=try Fixture(); defer {f.cleanup()}
        let a=try FileMetadata.read(f.file("a")),b=try FileMetadata.read(f.file("b"))
        try await f.catalog.insert([a,b])
        _=try await DuplicateDetector().analyze(catalog:f.catalog) {_ in}
        try await f.catalog.resetScan();try await f.catalog.insert([a,b])
        let engine=CleanupEngine(catalog:f.catalog,operations:FixtureTrash(root:f.root))
        do {_=try await engine.clean(confirmed:[a,b]);XCTFail("Every copy must not be approved")} catch {}
        XCTAssertTrue(FileManager.default.fileExists(atPath:a.path));XCTAssertTrue(FileManager.default.fileExists(atPath:b.path))
        let history=try await f.catalog.history();XCTAssertTrue(history.isEmpty)
        let keepers=try await f.catalog.duplicateKeepers(for:[a]);XCTAssertEqual(keepers[a.path]?.path,b.path)
    }
    func testEmptyFilesAreExactDuplicates() async throws {
        let f=try Fixture();defer{f.cleanup()}
        let a=try FileMetadata.read(f.file("a",content:"")),b=try FileMetadata.read(f.file("b",content:""))
        try await f.catalog.insert([a,b]);let report=try await DuplicateDetector().analyze(catalog:f.catalog){_ in}
        XCTAssertEqual(report.candidateCount,2);XCTAssertEqual(report.groups.first?.totalCopies,2)
        XCTAssertEqual(report.groups.first?.files.first?.logical,0)
    }
    func testChangedCatalogCannotPublishStaleAnalysis() async throws {
        let f=try Fixture();defer{f.cleanup()}
        let a=try FileMetadata.read(f.file("a")),b=try FileMetadata.read(f.file("b"))
        try await f.catalog.insert([a,b]);let catalog=f.catalog
        do {
            _=try await DuplicateDetector().analyze(catalog:catalog){ count in if count == 1 {try? await catalog.resetScan()} }
            XCTFail("Scan generation changed")
        } catch StorageError.refused(let key) {XCTAssertEqual(key,"error.analysisChanged")}
    }
    func testDistinctSamplesAvoidFullContentPass() async throws {
        let f=try Fixture();defer{f.cleanup()}
        var records:[FileRecord]=[]
        for i in 0..<20 {records.append(try FileMetadata.read(f.file("\(i)",content:String(format:"%08d",i))))}
        try await f.catalog.insert(records);let reader=CountingReader()
        let report=try await DuplicateDetector(reader:reader).analyze(catalog:f.catalog){_ in}
        XCTAssertEqual(report.candidateCount,20);XCTAssertEqual(reader.fullReads,0);XCTAssertTrue(report.groups.isEmpty)
    }
}

final class DuplicateStressTests: XCTestCase {
    func test25000RealCandidates() async throws {try await stress(25000)}
    func test50000RealCandidates() async throws {try await stress(50000)}
    private func stress(_ count:Int) async throws {
        guard ProcessInfo.processInfo.environment["SPACEMITHRA_STRESS"] == "1" else {throw XCTSkip("Set SPACEMITHRA_STRESS=1 for large real-file fixtures")}
        let f=try Fixture();defer{f.cleanup()}
        let root=f.root.appendingPathComponent("scan",isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let heartbeat=Task { @MainActor in
            var previous=Date(), maximum:TimeInterval=0
            while !Task.isCancelled {
                do {try await Task.sleep(for:.milliseconds(50))} catch {break}
                let now=Date();maximum=max(maximum,now.timeIntervalSince(previous));previous=now
            }
            return maximum
        }
        defer {heartbeat.cancel()}
        var before=rusage();getrusage(RUSAGE_SELF,&before)
        let start=Date(), payload=Data([42])
        for i in 0..<count {try payload.write(to:root.appendingPathComponent(String(format:"%06d",i)))}
        let created=Date()
        let scan=try await StorageScanner().scan(root:root,catalog:f.catalog){_ in}
        let scanned=Date()
        let report=try await DuplicateDetector().analyze(catalog:f.catalog){_ in}
        let analyzed=Date()
        XCTAssertEqual(scan.count,count);XCTAssertEqual(report.candidateCount,count)
        XCTAssertEqual(report.groups.first?.totalCopies,count);XCTAssertEqual(report.groups.first?.files.count,100)
        XCTAssertEqual(report.skippedCount,0);XCTAssertEqual(report.hashedCount,count)
        let last=try await f.catalog.duplicateMembers(id:try XCTUnwrap(report.groups.first?.id),offset:count-100)
        XCTAssertEqual(last.count,100)
        heartbeat.cancel();let gap=await heartbeat.value
        var usage=rusage();getrusage(RUSAGE_SELF,&usage)
        let cpu=Double(usage.ru_utime.tv_sec-before.ru_utime.tv_sec)+Double(usage.ru_utime.tv_usec-before.ru_utime.tv_usec)/1_000_000+Double(usage.ru_stime.tv_sec-before.ru_stime.tv_sec)+Double(usage.ru_stime.tv_usec-before.ru_stime.tv_usec)/1_000_000
        print("PERFORMANCE: process peak RSS=\(Double(usage.ru_maxrss)/1_048_576) MiB; CPU=\(cpu)s; MainActor maximum heartbeat interval=\(gap)s (50ms requested, test harness, not a rendering benchmark)")
        print("STRESS \(count): create=\(created.timeIntervalSince(start))s scan=\(scanned.timeIntervalSince(created))s analyze=\(analyzed.timeIntervalSince(scanned))s; preview=100 copies; all members pageable")
    }
}
