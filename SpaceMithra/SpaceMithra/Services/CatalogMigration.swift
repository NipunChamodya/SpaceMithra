import Foundation
import SQLite3

public func fileSearchKey(_ value:String)->String {
    value.folding(options:.caseInsensitive,locale:Locale(identifier:"en_US_POSIX")).precomposedStringWithCanonicalMapping
}
extension Catalog {
    static func migrateFileColumns(_ db:OpaquePointer) throws {
        var info:OpaquePointer?
        guard sqlite3_prepare_v2(db,"PRAGMA table_info(files)",-1,&info,nil) == SQLITE_OK else {throw StorageError.database("Cannot inspect catalog schema")}
        var columns:Set<String>=[]
        while sqlite3_step(info) == SQLITE_ROW {if let raw=sqlite3_column_text(info,1){columns.insert(String(cString:raw))}}
        sqlite3_finalize(info)
        let missing=[("logical_size","INTEGER NOT NULL DEFAULT 0"),("modified","REAL"),("search_name","TEXT NOT NULL DEFAULT ''")].filter{!columns.contains($0.0)}
        if !missing.isEmpty {
            try execute(db,"BEGIN IMMEDIATE")
            do {
                for (name,type) in missing {try execute(db,"ALTER TABLE files ADD COLUMN \(name) \(type)")}
                try execute(db,"UPDATE files SET logical_size=CASE WHEN directory=1 THEN size ELSE COALESCE(json_extract(CAST(payload AS TEXT),'$.logical'),size) END,modified=json_extract(CAST(payload AS TEXT),'$.modified')")
                var after=""
                while true {
                    var read:OpaquePointer?
                    guard sqlite3_prepare_v2(db,"SELECT path,name FROM files WHERE path>? ORDER BY path LIMIT 256",-1,&read,nil) == SQLITE_OK else {throw StorageError.database("Cannot migrate names")}
                    _=after.withCString{sqlite3_bind_text(read,1,$0,-1,unsafeBitCast(-1,to:sqlite3_destructor_type.self))}
                    var page:[(String,String)]=[]
                    var step=sqlite3_step(read)
                    while step == SQLITE_ROW {
                        if let path=sqlite3_column_text(read,0),let name=sqlite3_column_text(read,1){page.append((String(cString:path),String(cString:name)))}
                        step=sqlite3_step(read)
                    }
                    sqlite3_finalize(read)
                    guard step == SQLITE_DONE else {throw StorageError.database("Name migration failed")}
                    if page.isEmpty {break}
                    var write:OpaquePointer?
                    guard sqlite3_prepare_v2(db,"UPDATE files SET search_name=? WHERE path=?",-1,&write,nil) == SQLITE_OK else {throw StorageError.database("Cannot save migrated names")}
                    for (path,name) in page {
                        sqlite3_reset(write);sqlite3_clear_bindings(write)
                        _=fileSearchKey(name).withCString{sqlite3_bind_text(write,1,$0,-1,unsafeBitCast(-1,to:sqlite3_destructor_type.self))}
                        _=path.withCString{sqlite3_bind_text(write,2,$0,-1,unsafeBitCast(-1,to:sqlite3_destructor_type.self))}
                        guard sqlite3_step(write) == SQLITE_DONE else {sqlite3_finalize(write);throw StorageError.database("Cannot save migrated name")}
                    }
                    sqlite3_finalize(write);after=page.last?.0 ?? after
                }
                try execute(db,"COMMIT")
            } catch {try? execute(db,"ROLLBACK");throw error}
        }
        try execute(db,"CREATE INDEX IF NOT EXISTS files_logical_idx ON files(logical_size); CREATE INDEX IF NOT EXISTS files_modified_idx ON files(modified); PRAGMA user_version=2;")
    }
}
