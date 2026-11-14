import Foundation
import SQLite3

public struct DuplicateRun: Sendable {
    public let id: String
    public let generation: Int64
    public let resumed: Bool
    public let candidates: Int
}
struct DuplicateWorkUpdate: Sendable {
    let path: String
    let state: String
    var sample: String? = nil
    var hash: String? = nil
    var message: String? = nil
}
extension Catalog {
    private func scanGeneration() throws -> Int64 {
        let s = try statement("SELECT value FROM scan_generation WHERE id=1"); defer { sqlite3_finalize(s) }
        guard sqlite3_step(s) == SQLITE_ROW else { throw StorageError.database("Missing scan generation") }
        return sqlite3_column_int64(s,0)
    }
    func ensureRun(_ run: DuplicateRun) throws {
        guard try scanGeneration() == run.generation else { throw StorageError.refused("error.analysisChanged") }
    }
    public func canResumeDuplicates() throws -> Bool {
        let s = try statement("SELECT generation,complete FROM duplicate_state WHERE id=1"); defer { sqlite3_finalize(s) }
        let generation = try scanGeneration()
        return sqlite3_step(s) == SQLITE_ROW && sqlite3_column_int64(s,0) == generation && sqlite3_column_int(s,1) == 0
    }
    public func beginDuplicates() throws -> DuplicateRun {
        let generation = try scanGeneration()
        let s = try statement("SELECT generation,run,complete FROM duplicate_state WHERE id=1"); defer { sqlite3_finalize(s) }
        if sqlite3_step(s) == SQLITE_ROW, sqlite3_column_int64(s,0) == generation, sqlite3_column_int(s,2) == 0, let raw = sqlite3_column_text(s,1) {
            return DuplicateRun(id: String(cString: raw), generation: generation, resumed: true, candidates: try duplicateCount())
        }
        let id = UUID().uuidString
        try execute("BEGIN IMMEDIATE")
        // SQL runs on the catalog actor. Cancellation interrupts the large seed statement.
        sqlite3_progress_handler(db, 10000, { _ in Task.isCancelled ? 1 : 0 }, nil)
        do {
            try execute("DELETE FROM duplicate_work; DELETE FROM duplicate_state;")
            let state = try statement("INSERT INTO duplicate_state VALUES(1,?,?,0)")
            sqlite3_bind_int64(state,1,generation); bind(id,2,state)
            do { try finish(state) } catch { sqlite3_finalize(state); throw error }; sqlite3_finalize(state)
            try execute("""
                INSERT OR IGNORE INTO duplicate_work(path,size,payload,device,inode,state)
                SELECT path,size,payload,CAST(payload AS TEXT)->'$.identity.device',CAST(payload AS TEXT)->'$.identity.inode','pending'
                FROM files WHERE directory=0 AND size>=0 AND size=json_extract(CAST(payload AS TEXT),'$.identity.size')
                AND category!='cloud' AND json_extract(CAST(payload AS TEXT),'$.isRegular')=1
                AND json_extract(CAST(payload AS TEXT),'$.isSymlink')=0 AND json_extract(CAST(payload AS TEXT),'$.inPackage')=0
                AND json_extract(CAST(payload AS TEXT),'$.isPackage')=0 AND json_extract(CAST(payload AS TEXT),'$.cloud')=0
                AND json_extract(CAST(payload AS TEXT),'$.identity.links')=1
                AND size IN (SELECT size FROM files WHERE directory=0 GROUP BY size HAVING COUNT(*)>1)
                ORDER BY path
                """)
            sqlite3_progress_handler(db,0,nil,nil)
            try execute("COMMIT")
        } catch {
            sqlite3_progress_handler(db,0,nil,nil); try? execute("ROLLBACK")
            if Task.isCancelled { throw CancellationError() }; throw error
        }
        return DuplicateRun(id:id,generation:generation,resumed:false,candidates:try duplicateCount())
    }
    func duplicateCount(state: String? = nil) throws -> Int {
        let s = try statement("SELECT COUNT(*) FROM duplicate_work" + (state == nil ? "" : " WHERE state=?")); defer { sqlite3_finalize(s) }
        if let state { bind(state,1,s) }
        guard sqlite3_step(s) == SQLITE_ROW else { throw StorageError.database("Cannot read analysis count") }
        return Int(sqlite3_column_int64(s,0))
    }
    func duplicateBatch(_ run: DuplicateRun, state: String, limit: Int = 128) throws -> [FileRecord] {
        try ensureRun(run)
        let s = try statement("SELECT payload FROM duplicate_work WHERE state=? ORDER BY size DESC,path LIMIT \(min(128,max(1,limit)))")
        defer { sqlite3_finalize(s) }; bind(state,1,s)
        return try decodeDuplicateRows(s)
    }
    private func decodeDuplicateRows(_ s: OpaquePointer) throws -> [FileRecord] {
        var records: [FileRecord] = [], step = sqlite3_step(s)
        while step == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(s,0) else { throw StorageError.database("Missing duplicate record") }
            records.append(try JSONDecoder().decode(FileRecord.self, from: Data(bytes: bytes,count:Int(sqlite3_column_bytes(s,0)))))
            step = sqlite3_step(s)
        }
        guard step == SQLITE_DONE else { throw StorageError.database("Cannot read duplicate records") }
        return records
    }
    func saveDuplicateUpdates(_ run: DuplicateRun, updates: [DuplicateWorkUpdate]) throws {
        try ensureRun(run); try execute("BEGIN IMMEDIATE")
        do {
            let s = try statement("UPDATE duplicate_work SET state=?,sample=COALESCE(?,sample),hash=COALESCE(?,hash),message=? WHERE path=?")
            defer { sqlite3_finalize(s) }
            for u in updates {
                sqlite3_reset(s); sqlite3_clear_bindings(s); bind(u.state,1,s)
                if let sample=u.sample { bind(sample,2,s) }
                if let hash=u.hash { bind(hash,3,s) }
                if let message=u.message { bind(message,4,s) }
                bind(u.path,5,s); try finish(s)
            }
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
    func prepareFullHashes(_ run: DuplicateRun) throws {
        try ensureRun(run)
        try execute("UPDATE duplicate_work SET state='unique' WHERE state='sampled' AND (size,sample) NOT IN (SELECT size,sample FROM duplicate_work WHERE sample IS NOT NULL GROUP BY size,sample HAVING COUNT(*)>1)")
        try execute("UPDATE duplicate_work SET state='hashing' WHERE state='sampled'")
    }
    func prepareDuplicateVerification(_ run: DuplicateRun) throws {
        try ensureRun(run); try execute("UPDATE duplicate_work SET state='hashed' WHERE state='verified'")
    }
    func publishDuplicates(_ run: DuplicateRun) throws {
        try ensureRun(run); try execute("BEGIN IMMEDIATE")
        do {
            let s = try statement("INSERT OR REPLACE INTO duplicate_results SELECT CAST(size AS TEXT)||':'||hash,path,payload,size,? FROM duplicate_work WHERE state='verified' AND (size,hash) IN (SELECT size,hash FROM duplicate_work WHERE state='verified' GROUP BY size,hash HAVING COUNT(*)>1)")
            defer { sqlite3_finalize(s) }; bind(run.id,1,s); try finish(s)
            try execute("UPDATE duplicate_state SET complete=1 WHERE id=1"); try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
    public func duplicateGroups(offset: Int = 0, limit: Int = 200) throws -> [DuplicateGroup] {
        let s = try statement("SELECT digest,COUNT(*) FROM duplicate_results WHERE run=(SELECT run FROM duplicate_state WHERE id=1 AND complete=1 AND generation=(SELECT value FROM scan_generation WHERE id=1)) GROUP BY digest HAVING COUNT(*)>1 ORDER BY MAX(size) DESC,digest LIMIT \(min(200,max(1,limit))) OFFSET \(max(0,offset))")
        defer { sqlite3_finalize(s) }
        var result: [DuplicateGroup] = [], step = sqlite3_step(s)
        while step == SQLITE_ROW {
            guard let raw=sqlite3_column_text(s,0) else { throw StorageError.database("Missing duplicate group") }
            let id=String(cString:raw), count=Int(sqlite3_column_int64(s,1))
            result.append(DuplicateGroup(id:id,files:try duplicateMembers(id: id),totalCopies:count))
            step=sqlite3_step(s)
        }
        guard step == SQLITE_DONE else { throw StorageError.database("Cannot read duplicate groups") }; return result
    }
    public func duplicateMembers(id: String, offset: Int = 0, limit: Int = 100) throws -> [FileRecord] {
        let s = try statement("SELECT payload FROM duplicate_results WHERE digest=? AND run=(SELECT run FROM duplicate_state WHERE id=1 AND complete=1 AND generation=(SELECT value FROM scan_generation WHERE id=1)) ORDER BY path LIMIT \(min(100,max(1,limit))) OFFSET \(max(0,offset))")
        defer { sqlite3_finalize(s) }; bind(id,1,s); return try decodeDuplicateRows(s)
    }
    func duplicateReport() throws -> DuplicateReport {
        let s = try statement("SELECT COUNT(*),SUM(CASE WHEN state='skipped' THEN 1 ELSE 0 END),SUM(CASE WHEN hash IS NOT NULL THEN 1 ELSE 0 END) FROM duplicate_work")
        defer { sqlite3_finalize(s) }
        guard sqlite3_step(s) == SQLITE_ROW else { throw StorageError.database("Cannot read duplicate summary") }
        let candidateCount=Int(sqlite3_column_int64(s,0)), skipped=Int(sqlite3_column_int64(s,1)), hashed=Int(sqlite3_column_int64(s,2))
        let groups = try statement("SELECT COUNT(*) FROM (SELECT digest FROM duplicate_results WHERE run=(SELECT run FROM duplicate_state WHERE id=1 AND complete=1 AND generation=(SELECT value FROM scan_generation WHERE id=1)) GROUP BY digest HAVING COUNT(*)>1)")
        defer { sqlite3_finalize(groups) }; guard sqlite3_step(groups) == SQLITE_ROW else { throw StorageError.database("Cannot read group count") }
        let errors = try statement("SELECT path,message FROM duplicate_work WHERE state='skipped' ORDER BY path LIMIT 200")
        defer { sqlite3_finalize(errors) }; var issues:[ScanIssue]=[]; var step=sqlite3_step(errors)
        while step == SQLITE_ROW {
            if let path=sqlite3_column_text(errors,0),let message=sqlite3_column_text(errors,1) { issues.append(ScanIssue(path:String(cString:path),message:String(cString:message))) }
            step=sqlite3_step(errors)
        }
        guard step == SQLITE_DONE else { throw StorageError.database("Cannot read duplicate issues") }
        return DuplicateReport(groups:try duplicateGroups(),issues:issues,skippedCount:skipped,hashedCount:hashed,candidateCount:candidateCount,totalGroups:Int(sqlite3_column_int64(groups,0)))
    }
}

extension Catalog {
    /// Persistent proofs apply even when the UI is showing another page or an earlier scan.
    public func duplicateKeepers(for records: [FileRecord]) async throws -> [String: FileRecord] {
        guard !records.isEmpty else { return [:] }
        try execute("DELETE FROM duplicate_selected")
        let insert = try statement("INSERT OR REPLACE INTO duplicate_selected VALUES(?,?)")
        defer { sqlite3_finalize(insert) }
        try execute("BEGIN IMMEDIATE")
        do {
            for file in records {
                try Task.checkCancellation()
                sqlite3_reset(insert); sqlite3_clear_bindings(insert)
                bind(file.path,1,insert); bind(try JSONEncoder().encode(file),2,insert); try finish(insert)
            }
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
        let match = ["device","inode","size","modified","changed","links"].map {
            "(CAST(r.payload AS TEXT)->'$.identity.\($0)')=(CAST(s.payload AS TEXT)->'$.identity.\($0)')"
        }.joined(separator:" AND ")
        let groups = try statement("SELECT DISTINCT r.digest FROM duplicate_results r JOIN duplicate_selected s ON r.path=s.path WHERE \(match)")
        defer { sqlite3_finalize(groups) }
        var constraints:[String:FileRecord]=[:], step=sqlite3_step(groups)
        while step == SQLITE_ROW {
            guard let raw=sqlite3_column_text(groups,0) else { throw StorageError.database("Missing duplicate constraint") }
            let digest=String(cString:raw)
            var keeper:FileRecord?, after=""
            while keeper == nil {
                try Task.checkCancellation()
                let candidates=try statement("SELECT payload FROM duplicate_results WHERE digest=? AND path>? AND path NOT IN (SELECT path FROM duplicate_selected) ORDER BY path LIMIT 128")
                bind(digest,1,candidates);bind(after,2,candidates)
                let page:[FileRecord]
                do { page=try decodeDuplicateRows(candidates) } catch {sqlite3_finalize(candidates);throw error}
                sqlite3_finalize(candidates)
                if page.isEmpty {break}
                for file in page {
                    try Task.checkCancellation()
                    let url=URL(fileURLWithPath:file.path)
                    if url.resolvingSymlinksInPath().path == file.path,
                       let fresh=try? FileMetadata.read(url), fresh.identity == file.identity, fresh.isRegular == true, !fresh.isSymlink {
                        keeper=file;break
                    }
                }
                after=page.last?.path ?? after
            }
            guard let keeper else { throw StorageError.refused("duplicate.keepOne") }
            let selected=try statement("SELECT s.path FROM duplicate_results r JOIN duplicate_selected s ON r.path=s.path WHERE r.digest=? AND \(match)")
            bind(digest,1,selected);var selectedStep=sqlite3_step(selected)
            while selectedStep == SQLITE_ROW {
                if let path=sqlite3_column_text(selected,0) {constraints[String(cString:path)]=keeper}
                selectedStep=sqlite3_step(selected)
            }
            sqlite3_finalize(selected)
            guard selectedStep == SQLITE_DONE else {throw StorageError.database("Cannot read keeper constraints")}
            step=sqlite3_step(groups)
        }
        guard step == SQLITE_DONE else {throw StorageError.database("Cannot validate duplicate keepers")}
        return constraints
    }
}
