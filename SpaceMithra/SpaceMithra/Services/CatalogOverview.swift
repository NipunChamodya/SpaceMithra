import Foundation
import SQLite3

public struct ScanCatalogContext:Codable,Sendable {
    public var root:String
    public var state:ScanState
    public var started:Date
    public var finished:Date?
    public var count:Int
    public var errors:Int
}
public struct ReviewSuggestion:Identifiable,Sendable {
    public let id:String
    public let count:Int
    public let bytes:Int64
}
extension Catalog {
    public func saveScanContext(_ context:ScanCatalogContext) throws {try save(context,table:"scan_context",id:"current")}
    public func scanContext() throws -> ScanCatalogContext? {let rows:[ScanCatalogContext]=try read(table:"scan_context");return rows.first}
    public func dashboardBuckets(home:URL=FileManager.default.homeDirectoryForCurrentUser) throws -> [String:Int64] {
        let s=try statement("SELECT CASE WHEN path>=? AND path<? THEN 'downloads' ELSE category END,COALESCE(SUM(size),0) FROM files WHERE directory=0 GROUP BY 1")
        defer{sqlite3_finalize(s)}
        let prefix=home.appendingPathComponent("Downloads",isDirectory:true).path + "/"
        bind(prefix,1,s);bind(String(prefix.dropLast())+"0",2,s)
        var result:[String:Int64]=[:],step=sqlite3_step(s)
        let direct:Set<String>=["applications","images","videos","documents","downloads","caches","developer"]
        while step == SQLITE_ROW {
            if let raw=sqlite3_column_text(s,0) {
                let category=String(cString:raw),key=direct.contains(category) ? category:"other"
                let(sum,overflow)=(result[key] ?? 0).addingReportingOverflow(sqlite3_column_int64(s,1))
                result[key]=overflow ? Int64.max:sum
            }
            step=sqlite3_step(s)
        }
        guard step == SQLITE_DONE else {throw StorageError.database("Cannot read dashboard totals")};return result
    }
    public func suggestions(home:URL=FileManager.default.homeDirectoryForCurrentUser,now:Date=Date()) throws -> [ReviewSuggestion] {
        let protected=try protections().filter{$0.expires.map{$0>now} ?? true}
        // Recommendation summaries are optional; never exceed SQLite bind limits.
        guard protected.count<=100 else {return []}
        let downloads=home.appendingPathComponent("Downloads",isDirectory:true).path + "/"
        let homePrefix=home.path + "/", library=home.appendingPathComponent("Library",isDirectory:true).path + "/"
        let cachePrefixes=StorageRule.all.filter(\.isCache).map{home.appendingPathComponent($0.relativePath,isDirectory:true).path + "/"}
        let cacheClause=cachePrefixes.map{_ in "(path>=? AND path<?)"}.joined(separator:" OR ")
        let types="directory=0 AND json_extract(CAST(payload AS TEXT),'$.isRegular')=1 AND json_extract(CAST(payload AS TEXT),'$.inPackage')=0 AND json_extract(CAST(payload AS TEXT),'$.identity.links')=1"
        let conditions:[(String,String,[String])]=[
            ("installers","category='installers' AND path>=? AND path<? AND modified<\(now.addingTimeInterval(-30*86400).timeIntervalSinceReferenceDate)",[downloads,String(downloads.dropLast())+"0"]),
            ("videos","category='videos' AND logical_size>=100000000 AND path>=? AND path<? AND NOT(path>=? AND path<?)",[homePrefix,String(homePrefix.dropLast())+"0",library,String(library.dropLast())+"0"]),
            ("caches","category='caches' AND (\(cacheClause))",cachePrefixes.flatMap{[$0,String($0.dropLast())+"0"]})]
        var result:[ReviewSuggestion]=[]
        for(id,condition,parameters) in conditions {
            var clause=types + " AND " + condition, values=parameters
            for rule in protected {
                clause += " AND path!=?";values.append(rule.path)
                if rule.descendants {let prefix=rule.path == "/" ? "/":rule.path+"/";clause += " AND NOT(path>=? AND path<?)";values += [prefix,String(prefix.dropLast())+"0"]}
            }
            let s=try statement("SELECT COUNT(*),COALESCE(SUM(size),0) FROM files WHERE \(clause)")
            for(index,value) in values.enumerated(){bind(value,Int32(index+1),s)}
            guard sqlite3_step(s) == SQLITE_ROW else {sqlite3_finalize(s);throw StorageError.database("Cannot read review suggestions")}
            let count=Int(sqlite3_column_int64(s,0)),bytes=sqlite3_column_int64(s,1)
            if count>0 {result.append(ReviewSuggestion(id:id,count:count,bytes:bytes))};sqlite3_finalize(s)
        }
        return result
    }
}
