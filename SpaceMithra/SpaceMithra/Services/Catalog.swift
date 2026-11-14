import Foundation
import SQLite3

public actor Catalog {
    private let connection: DatabaseConnection
    var db: OpaquePointer? { connection.pointer }
    public init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var handle: OpaquePointer?
        guard sqlite3_open(url.path, &handle) == SQLITE_OK, let handle else {
            if let handle { sqlite3_close(handle) }
            throw StorageError.database("Unable to open catalog")
        }
        connection = DatabaseConnection(handle)
        do {
            try Self.execute(handle, "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=3000; PRAGMA temp_store=FILE; PRAGMA cache_size=-16384; CREATE TABLE IF NOT EXISTS files(path TEXT PRIMARY KEY,parent TEXT,name TEXT,category TEXT,directory INTEGER,size INTEGER,allocated INTEGER,payload BLOB); CREATE INDEX IF NOT EXISTS parent_idx ON files(parent); CREATE INDEX IF NOT EXISTS size_idx ON files(size); CREATE TABLE IF NOT EXISTS protections(id TEXT PRIMARY KEY,payload BLOB); CREATE TABLE IF NOT EXISTS history(id TEXT PRIMARY KEY,payload BLOB); CREATE TABLE IF NOT EXISTS trends(date REAL,bytes INTEGER); CREATE TABLE IF NOT EXISTS previous_records(path TEXT PRIMARY KEY,payload BLOB); CREATE TABLE IF NOT EXISTS scan_issues(id TEXT PRIMARY KEY,path TEXT,message TEXT); CREATE TABLE IF NOT EXISTS scan_context(id TEXT PRIMARY KEY,payload BLOB); CREATE TABLE IF NOT EXISTS scan_generation(id INTEGER PRIMARY KEY,value INTEGER); INSERT OR IGNORE INTO scan_generation VALUES(1,0); CREATE TABLE IF NOT EXISTS duplicate_state(id INTEGER PRIMARY KEY,generation INTEGER,run TEXT,complete INTEGER); CREATE TABLE IF NOT EXISTS duplicate_work(path TEXT PRIMARY KEY,size INTEGER,payload BLOB,device TEXT,inode TEXT,sample TEXT,hash TEXT,state TEXT,message TEXT,UNIQUE(device,inode)); CREATE INDEX IF NOT EXISTS duplicate_work_stage ON duplicate_work(state,size,path); CREATE INDEX IF NOT EXISTS duplicate_work_sample ON duplicate_work(size,sample); CREATE TABLE IF NOT EXISTS duplicate_results(digest TEXT,path TEXT,payload BLOB,size INTEGER,run TEXT,PRIMARY KEY(digest,path)); CREATE INDEX IF NOT EXISTS duplicate_result_path ON duplicate_results(path); CREATE INDEX IF NOT EXISTS duplicate_result_run ON duplicate_results(run,digest); CREATE TABLE IF NOT EXISTS duplicate_selected(path TEXT PRIMARY KEY,payload BLOB); CREATE TABLE IF NOT EXISTS scan_directories(device TEXT,inode TEXT,PRIMARY KEY(device,inode)); CREATE TABLE IF NOT EXISTS scan_inodes(device TEXT,inode TEXT,PRIMARY KEY(device,inode));")
            try Self.migrateFileColumns(handle)
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(handle, "PRAGMA quick_check", -1, &statement, nil) == SQLITE_OK else { throw StorageError.database("Catalog validation failed") }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW, let result = sqlite3_column_text(statement, 0), String(cString: result) == "ok" else { throw StorageError.database("Catalog is corrupt; preserve it for recovery and open a new catalog manually.") }
        } catch { throw error }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.deletingLastPathComponent().path)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func execute(_ db: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw StorageError.database(String(cString: sqlite3_errmsg(db))) }
    }
    func execute(_ sql: String) throws { guard let db else { throw StorageError.database("Catalog closed") }; try Self.execute(db, sql) }
    func statement(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard let db, sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw StorageError.database("Catalog query failed") }; return stmt
    }
    func bind(_ value: String, _ position: Int32, _ stmt: OpaquePointer) {
        _ = value.withCString { sqlite3_bind_text(stmt, position, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    }
    func bind(_ data: Data, _ position: Int32, _ stmt: OpaquePointer) {
        _ = data.withUnsafeBytes { sqlite3_bind_blob(stmt, position, $0.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    }
    func finish(_ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw StorageError.database("Catalog write failed") }
    }
    public func resetScan() throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("UPDATE scan_generation SET value=value+1 WHERE id=1; DELETE FROM scan_context; DELETE FROM previous_records; INSERT INTO previous_records SELECT path,payload FROM files; DELETE FROM files; DELETE FROM scan_inodes; DELETE FROM scan_directories; DELETE FROM scan_issues;")
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
    public func cachedRecord(path: String, identity: Identity) throws -> FileRecord? {
        let stmt = try statement("SELECT payload FROM previous_records WHERE path=?")
        defer { sqlite3_finalize(stmt) }; bind(path, 1, stmt)
        let step = sqlite3_step(stmt)
        if step == SQLITE_DONE { return nil }
        guard step == SQLITE_ROW, let bytes = sqlite3_column_blob(stmt, 0) else { throw StorageError.database("Previous scan read failed") }
        let record = try JSONDecoder().decode(FileRecord.self, from: Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0))))
        return record.identity == identity ? record : nil
    }
    public func saveScanIssue(_ issue: ScanIssue) throws {
        let stmt = try statement("INSERT INTO scan_issues VALUES(?,?,?)"); defer { sqlite3_finalize(stmt) }
        bind(issue.id, 1, stmt); bind(issue.path, 2, stmt); bind(issue.message, 3, stmt); try finish(stmt)
    }
    public func scanIssues() throws -> [ScanIssue] {
        let stmt = try statement("SELECT id,path,message FROM scan_issues LIMIT 200"); defer { sqlite3_finalize(stmt) }
        var issues: [ScanIssue] = [], step = sqlite3_step(stmt)
        while step == SQLITE_ROW {
            guard let id = sqlite3_column_text(stmt, 0), let path = sqlite3_column_text(stmt, 1), let message = sqlite3_column_text(stmt, 2) else { throw StorageError.database("Missing scan issue") }
            issues.append(ScanIssue(id: String(cString: id), path: String(cString: path), message: String(cString: message)))
            step = sqlite3_step(stmt)
        }
        guard step == SQLITE_DONE else { throw StorageError.database("Scan issue read failed") }
        return issues
    }
    public func insert(_ records: [FileRecord]) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            let stmt = try statement("INSERT OR REPLACE INTO files(path,parent,name,category,directory,size,allocated,payload,logical_size,modified,search_name) VALUES(?,?,?,?,?,?,?,?,?,?,?)")
            defer { sqlite3_finalize(stmt) }
            for r in records {
                var contribution = r.logical
                var allocation = r.allocated
                if !r.isDirectory {
                    let inode = try statement("INSERT OR IGNORE INTO scan_inodes VALUES(?,?)")
                    bind(String(r.identity.device), 1, inode); bind(String(r.identity.inode), 2, inode)
                    do { try finish(inode) } catch { sqlite3_finalize(inode); throw error }
                    sqlite3_finalize(inode)
                    if sqlite3_changes(db) == 0 { contribution = 0; allocation = 0 }
                }
                sqlite3_reset(stmt); sqlite3_clear_bindings(stmt)
                bind(r.path, 1, stmt); bind(r.parent, 2, stmt); bind(r.name, 3, stmt); bind(r.category.rawValue, 4, stmt)
                sqlite3_bind_int(stmt, 5, r.isDirectory ? 1 : 0); sqlite3_bind_int64(stmt, 6, contribution)
                if let allocated = allocation { sqlite3_bind_int64(stmt, 7, allocated) } else { sqlite3_bind_null(stmt, 7) }
                bind(try JSONEncoder().encode(r), 8, stmt)
                sqlite3_bind_int64(stmt,9,r.logical)
                if let modified=r.modified {sqlite3_bind_double(stmt,10,modified.timeIntervalSinceReferenceDate)}
                bind(fileSearchKey(r.name),11,stmt);try finish(stmt)
            }
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
    public func registerDirectory(_ identity: Identity) throws -> Bool {
        let stmt = try statement("INSERT OR IGNORE INTO scan_directories VALUES(?,?)"); defer { sqlite3_finalize(stmt) }
        bind(String(identity.device), 1, stmt); bind(String(identity.inode), 2, stmt); try finish(stmt)
        return sqlite3_changes(db) != 0
    }
    public func storageSummary() throws -> ScanStorageSummary {
        let stmt = try statement("SELECT category,COALESCE(SUM(size),0),COALESCE(SUM(allocated),0),COUNT(*) FROM files WHERE directory=0 GROUP BY category")
        defer { sqlite3_finalize(stmt) }
        var result = ScanStorageSummary(), step = sqlite3_step(stmt)
        while step == SQLITE_ROW {
            guard let raw = sqlite3_column_text(stmt, 0), let category = FileCategory(rawValue: String(cString: raw)) else { throw StorageError.database("Invalid category") }
            let bytes = sqlite3_column_int64(stmt, 1)
            result.categoryBytes[category] = bytes; result.logical += bytes
            result.allocatedKnown += sqlite3_column_int64(stmt, 2); result.fileCount += Int(sqlite3_column_int64(stmt, 3))
            step = sqlite3_step(stmt)
        }
        guard step == SQLITE_DONE else { throw StorageError.database("Cannot read category totals") }
        let system = try statement("SELECT COALESCE(SUM(size),0) FROM files WHERE directory=0 AND (instr(path,'/System/')=1 OR instr(path,'/usr/')=1 OR instr(path,'/bin/')=1 OR instr(path,'/sbin/')=1)")
        defer { sqlite3_finalize(system) }
        guard sqlite3_step(system) == SQLITE_ROW else { throw StorageError.database("Cannot read system estimate") }
        result.systemLogical = sqlite3_column_int64(system, 0)
        return result
    }
    public func totalBytes() throws -> Int64 {
        let stmt = try statement("SELECT COALESCE(SUM(size),0) FROM files WHERE directory=0")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw StorageError.database("Cannot read totals") }
        return sqlite3_column_int64(stmt, 0)
    }
    public func aggregateDirectories(shouldCancel: @Sendable () async -> Bool = { false }) async throws {
        // One depth at a time: memory is bounded even for very large trees.
        let depths = try statement("SELECT MAX(CASE WHEN path='/' THEN 0 ELSE length(path)-length(replace(path,'/','')) END) FROM files WHERE directory=1")
        defer { sqlite3_finalize(depths) }
        guard sqlite3_step(depths) == SQLITE_ROW else { return }
        let maxDepth = Int(sqlite3_column_int(depths, 0))
        for depth in stride(from: maxDepth, through: 0, by: -1) {
            if await shouldCancel() { throw CancellationError() }
            try execute("UPDATE files AS p SET size=COALESCE((SELECT SUM(c.size) FROM files c WHERE c.parent=p.path),0), allocated=(SELECT SUM(c.allocated) FROM files c WHERE c.parent=p.path) WHERE directory=1 AND CASE WHEN path='/' THEN 0 ELSE length(path)-length(replace(path,'/','')) END=\(depth)")
        }
        try execute("UPDATE files SET logical_size=size WHERE directory=1")
    }
    public func list(parent: String? = nil, search: String = "", category: FileCategory? = nil, biggest: Bool = false, sort: String = "size", pathPrefix: String? = nil, developerOnly: Bool = false, directoriesOnly: Bool = false, minimumSize: Int64 = 0, extensionFilter: String = "", modifiedAfter: Date? = nil, modifiedBefore: Date? = nil, showHidden: Bool = true, overviewBucket: String? = nil, offset: Int = 0, limit: Int = 300) throws -> [FileRecord] {
        var predicates = ["1=1"], values: [String] = []
        if let pathPrefix {
            let prefix=pathPrefix == "/" ? "/" : pathPrefix + "/"
            predicates.append("(path=? OR (path>=? AND path<?))");values += [pathPrefix,prefix,String(prefix.dropLast())+"0"]
        }
        if minimumSize > 0 {predicates.append("logical_size>=\(minimumSize)")}
        if !showHidden {predicates.append("substr(name,1,1)!='.'")}
        if !extensionFilter.isEmpty {
            let suffix="." + fileSearchKey(extensionFilter.trimmingCharacters(in:CharacterSet(charactersIn:".")))
            predicates.append("substr(search_name,-length(?))=?");values += [suffix,suffix]
        }
        if let modifiedAfter {predicates.append("modified>=\(modifiedAfter.timeIntervalSinceReferenceDate)")}
        if let modifiedBefore {predicates.append("modified<=\(modifiedBefore.timeIntervalSinceReferenceDate)")}

        if developerOnly {
            let rules = StorageRule.all.filter { $0.group == "development" }
            predicates.append("(" + (["category='developer'"] + rules.map { _ in "(path=? OR instr(path,?)=1)" }).joined(separator: " OR ") + ")")
            for rule in rules { values += [rule.path, rule.path + "/"] }
        }
        if let parent { predicates.append("parent=?"); values.append(parent) }
        if !search.isEmpty { predicates.append("instr(search_name,?)>0"); values.append(fileSearchKey(search)) }
        if overviewBucket != nil {
            let prefix=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads",isDirectory:true).path + "/"
            predicates.append("NOT(path>=? AND path<?)");values += [prefix,String(prefix.dropLast())+"0"]
        }
        if overviewBucket == "other" {predicates.append("category NOT IN ('applications','images','videos','documents','caches','developer')")}
        if let category { predicates.append("category=?"); values.append(category.rawValue) }
        if directoriesOnly { predicates.append("directory=1") }
        if biggest { predicates.append("directory=0") }
        let order = sort == "name" ? "name COLLATE NOCASE" : sort == "type" ? "category,name" : sort == "date" ? "modified DESC,name" : "logical_size DESC,name"
        let stmt = try statement("SELECT payload,size,allocated FROM files WHERE \(predicates.joined(separator: " AND ")) ORDER BY \(order) LIMIT \(max(1,min(limit,1000))) OFFSET \(max(0,offset))")
        defer { sqlite3_finalize(stmt) }
        for (index, value) in values.enumerated() { bind(value, Int32(index + 1), stmt) }
        var result: [FileRecord] = []
        var step = sqlite3_step(stmt)
        while step == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(stmt, 0) else { throw StorageError.database("Missing catalog record") }
            var r = try JSONDecoder().decode(FileRecord.self, from: Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0))))
            if r.isDirectory {
                r.logical = sqlite3_column_int64(stmt, 1)
                r.allocated = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, 2)
            }
            result.append(r)
            step = sqlite3_step(stmt)
        }
        guard step == SQLITE_DONE else { throw StorageError.database("Catalog read failed") }
        return result
    }
    public func discoveredStorage() throws -> [DiscoveredStorage] {
        var result: [DiscoveredStorage] = []
        for rule in StorageRule.all {
            let stmt = try statement("SELECT COUNT(*),COALESCE(SUM(CASE WHEN directory=0 THEN size ELSE 0 END),0) FROM files WHERE path=? OR instr(path,?)=1")
            bind(rule.path, 1, stmt); bind(rule.path + "/", 2, stmt)
            if sqlite3_step(stmt) == SQLITE_ROW, sqlite3_column_int64(stmt, 0) > 0 {
                result.append(DiscoveredStorage(rule: rule, bytes: sqlite3_column_int64(stmt, 1)))
            }
            sqlite3_finalize(stmt)
        }
        return result
    }
    public func saveProtection(_ rule: Protection) throws { try save(rule, table: "protections", id: rule.id) }
    public func removeProtection(_ id: String) throws {
        let stmt = try statement("DELETE FROM protections WHERE id=?"); defer { sqlite3_finalize(stmt) }; bind(id, 1, stmt); try finish(stmt)
    }
    public func protections() throws -> [Protection] { try read(table: "protections") }
    public func history() throws -> [HistoryEntry] { try read(table: "history") }
    public func saveHistory(_ entry: HistoryEntry) throws { try save(entry, table: "history", id: entry.id) }
    func save<T: Encodable>(_ item: T, table: String, id: String) throws {
        let stmt = try statement("INSERT OR REPLACE INTO \(table)(id,payload) VALUES(?,?)"); defer { sqlite3_finalize(stmt) }
        bind(id, 1, stmt); bind(try JSONEncoder().encode(item), 2, stmt); try finish(stmt)
    }
    func read<T: Decodable>(table: String) throws -> [T] {
        let stmt = try statement("SELECT payload FROM \(table)"); defer { sqlite3_finalize(stmt) }
        var result: [T] = []
        var step = sqlite3_step(stmt)
        while step == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(stmt, 0) else { throw StorageError.database("Missing history or protection record") }
            result.append(try JSONDecoder().decode(T.self, from: Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0)))))
            step = sqlite3_step(stmt)
        }
        guard step == SQLITE_DONE else { throw StorageError.database("History or protection read failed") }
        return result
    }
    public func recordTrend(bytes: Int64) throws { try execute("INSERT INTO trends VALUES(\(Date().timeIntervalSince1970),\(bytes))") }
    public func trends() throws -> [(Date, Int64)] {
        let stmt = try statement("SELECT date,bytes FROM trends ORDER BY date DESC LIMIT 30"); defer { sqlite3_finalize(stmt) }
        var result: [(Date, Int64)] = []
        var step = sqlite3_step(stmt)
        while step == SQLITE_ROW {
            result.append((Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)), sqlite3_column_int64(stmt, 1)))
            step = sqlite3_step(stmt)
        }
        guard step == SQLITE_DONE else { throw StorageError.database("Trend read failed") }
        return result.reversed()
    }
}

// Lifetime wrapper closes the SQLite handle once the actor is released. Only Catalog
// accesses it; Sendable permits destruction after actor teardown without sharing use.
private final class DatabaseConnection: @unchecked Sendable {
    let pointer: OpaquePointer
    init(_ pointer: OpaquePointer) { self.pointer = pointer }
    deinit { sqlite3_close(pointer) }
}
