import Foundation
import SQLite3

public actor DeveloperAnalyzer {
    public init() {}
    public func discover(catalog: Catalog, home: URL = FileManager.default.homeDirectoryForCurrentUser, includeSystemLocations: Bool = true) async throws -> [DeveloperStorageEntry] {
        var entries:[String:DeveloperStorageEntry]=[:]
        for definition in DeveloperLocation.definitions where includeSystemLocations || !definition.absolute {
            try Task.checkCancellation()
            let url=definition.url(home:home)
            guard let metadata=try? FileMetadata.read(url), metadata.isDirectory, !metadata.isSymlink,
                  FileManager.default.isReadableFile(atPath:url.path) else {continue}
            let record=try await catalog.record(at: url.path)
            entries[url.path]=DeveloperStorageEntry(tool:definition.tool,icon:definition.icon,url:url,kind:definition.kind,logicalSize:record?.logical,inspectCommand:definition.inspectCommand)
        }
        var after=""
        while entries.count < 1000 {
            let page=try await catalog.developerDirectoryCandidates(after:after)
            if page.isEmpty {break}
            for record in page {
                try Task.checkCancellation()
                let url=URL(fileURLWithPath:record.path,isDirectory:true), parent=url.deletingLastPathComponent()
                guard !record.inPackage, FileManager.default.isReadableFile(atPath:record.path),
                      let fresh=try? FileMetadata.read(url), fresh.isDirectory, !fresh.isSymlink else {continue}
                func exists(_ name:String)->Bool {FileManager.default.fileExists(atPath:parent.appendingPathComponent(name).path)}
                let tool:String,kind:DeveloperStorageKind
                switch record.name {
                case "node_modules" where exists("package.json"):tool="Node.js";kind = .dependencyStore
                case let name where [".venv","venv"].contains(name) && FileManager.default.fileExists(atPath:url.appendingPathComponent("pyvenv.cfg").path):tool="Python";kind = .environment
                case "__pycache__":tool="Python";kind = .buildArtifact
                case "target" where exists("Cargo.toml"):tool="Rust";kind = .buildArtifact
                case ".build" where exists("Package.swift"):tool="Swift";kind = .buildArtifact
                case ".dart_tool" where exists("pubspec.yaml"):tool="Flutter / Dart";kind = .buildArtifact
                case "build" where exists("package.json") || exists("pyproject.toml") || exists("build.gradle") || exists("CMakeLists.txt") || exists("pubspec.yaml"):tool="Project";kind = .buildArtifact
                default:continue
                }
                entries[url.path]=DeveloperStorageEntry(tool:tool,icon:"hammer",url:url,kind:kind,logicalSize:record.logical,inspectCommand:nil)
                if entries.count >= 1000 {break}
            }
            after=page.last?.path ?? after
        }
        return entries.values.sorted { $0.tool == $1.tool ? $0.url.path < $1.url.path : $0.tool < $1.tool }
    }
}
extension Catalog {
    public func record(at path:String) throws -> FileRecord? {
        // Exact path is bound; no wildcard/name-based ownership inference.
        let statement = try statement("SELECT payload,size,allocated FROM files WHERE path=?")
        defer { sqlite3_finalize(statement) };bind(path,1,statement)
        guard sqlite3_step(statement) == SQLITE_ROW else {return nil}
        guard let raw=sqlite3_column_blob(statement,0) else {throw StorageError.database("Missing file metadata")}
        var file=try JSONDecoder().decode(FileRecord.self,from:Data(bytes:raw,count:Int(sqlite3_column_bytes(statement,0))))
        if file.isDirectory {file.logical=sqlite3_column_int64(statement,1);file.allocated=sqlite3_column_type(statement,2) == SQLITE_NULL ? nil : sqlite3_column_int64(statement,2)}
        return file
    }
    public func developerDirectoryCandidates(after:String) throws -> [FileRecord] {
        let s=try statement("SELECT payload,size FROM files WHERE directory=1 AND path>? AND name IN ('node_modules','.venv','venv','__pycache__','target','.build','.dart_tool','build') ORDER BY path LIMIT 128")
        defer {sqlite3_finalize(s)};bind(after,1,s)
        var result:[FileRecord]=[],step=sqlite3_step(s)
        while step == SQLITE_ROW {
            if let raw=sqlite3_column_blob(s,0) {
                var record=try JSONDecoder().decode(FileRecord.self,from:Data(bytes:raw,count:Int(sqlite3_column_bytes(s,0))))
                record.logical=sqlite3_column_int64(s,1);result.append(record)
            }
            step=sqlite3_step(s)
        }
        guard step == SQLITE_DONE else {throw StorageError.database("Cannot read developer directories")};return result
    }
}
