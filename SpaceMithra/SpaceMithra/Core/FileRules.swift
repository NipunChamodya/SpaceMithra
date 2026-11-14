import Foundation
import Darwin

public enum FileMetadata {
    public static func identity(_ path: String) throws -> Identity {
        var info = stat()
        guard lstat(path, &info) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return identity(from: info)
    }
    static func identity(from info: stat) -> Identity {
        Identity(device: UInt64(UInt32(bitPattern: info.st_dev)), inode: UInt64(info.st_ino), size: Int64(info.st_size),
                        modified: Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1e9,
                        changed: Double(info.st_ctimespec.tv_sec) + Double(info.st_ctimespec.tv_nsec) / 1e9,
                        links: UInt64(info.st_nlink))
    }
    public static func read(_ url: URL, inPackage: Bool = false, inspectAncestors: Bool = true) throws -> FileRecord {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isPackageKey, .fileSizeKey, .fileAllocatedSizeKey, .creationDateKey, .contentModificationDateKey, .contentAccessDateKey, .isUbiquitousItemKey, .typeIdentifierKey]
        let v = try url.resourceValues(forKeys: keys)
        let identity = try identity(url.path)
        var packageAncestor = inPackage
        if inspectAncestors && !packageAncestor {
            var parent = url.deletingLastPathComponent()
            while parent.path != "/" {
                if try parent.resourceValues(forKeys: [.isPackageKey]).isPackage == true { packageAncestor = true; break }
                let next = parent.deletingLastPathComponent()
                if next.path == parent.path { break }
                parent = next
            }
        }
        return FileRecord(path: url.path, parent: url.deletingLastPathComponent().path, name: url.lastPathComponent,
                          isDirectory: v.isDirectory ?? false, isRegular: v.isRegularFile, isSymlink: v.isSymbolicLink ?? false, inPackage: packageAncestor,
                          isPackage: v.isPackage ?? false, logical: v.isDirectory == true ? 0 : Int64(v.fileSize ?? 0),
                          allocated: v.fileAllocatedSize.map(Int64.init), created: v.creationDate, modified: v.contentModificationDate,
                          opened: v.contentAccessDate, identity: identity, category: Classifier.category(url, cloud: v.isUbiquitousItem ?? false), typeIdentifier: v.typeIdentifier, cloud: v.isUbiquitousItem ?? false)
    }
}
public enum Classifier {
    public static func recognizedCache(_ path: String) -> String? {
        StorageRule.all.first { $0.isCache && $0.matches(path) }?.owner
    }

    public static func category(_ url: URL, cloud: Bool) -> FileCategory {
        let p = url.path.lowercased(), ext = url.pathExtension.lowercased()
        if cloud || p.contains("/mobile documents/") || p.contains("/cloudstorage/") { return .cloud }
        let home = FileManager.default.homeDirectoryForCurrentUser.path.lowercased() + "/"
        if p.hasPrefix(home), let first = p.dropFirst(home.count).split(separator: "/").first,
           ["dropbox", "onedrive", "google drive", "googledrive"].contains(where: { first.hasPrefix($0) }) { return .cloud }
        if ext == "icloud" { return .cloud }
        if StorageRule.all.contains(where: { $0.isCache && $0.matches(url.path) }) { return .caches }
        if StorageRule.all.contains(where: { !$0.isCache && $0.matches(url.path) }) { return .developer }
        if p.contains("/library/caches/") || p.contains("/.npm/_cacache/") { return .caches }
        if p.contains("/library/developer/") || p.contains("/node_modules/") || ["swift", "rs", "py", "js", "o", "a"].contains(ext) { return .developer }
        if p.contains("/library/application support/") { return .support }
        if p.contains("/library/logs/") || ext == "log" { return .logs }
        if p.contains("/mobilesync/backup/") || ext == "backup" { return .backups }
        if ext == "app" { return .applications }
        if ["dmg", "pkg", "iso"].contains(ext) { return .installers }
        if ["zip", "gz", "tar", "7z", "rar", "xz"].contains(ext) { return .archives }
        if ["jpg", "jpeg", "png", "heic", "gif", "tiff", "raw", "svg"].contains(ext) { return .images }
        if ["mov", "mp4", "mkv", "avi", "m4v"].contains(ext) { return .videos }
        if ["mp3", "wav", "aac", "flac", "m4a"].contains(ext) { return .audio }
        if ["pdf", "txt", "docx", "pages", "xlsx", "numbers", "pptx", "key", "md", "rtf"].contains(ext) { return .documents }
        return .unknown
    }
}
public enum RiskEngine {
    public static func assess(_ file: FileRecord, protections: [Protection], now: Date = Date()) -> Assessment {
        let p = file.path
        let systemRoots = ["/System", "/Library", "/usr", "/bin", "/sbin", "/private", "/dev", "/Applications", "/Volumes/Preboot"]
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let prohibited = systemRoots.contains { p.lowercased() == $0.lowercased() || p.lowercased().hasPrefix($0.lowercased() + "/") }
            || p == home || p == home + "/.Trash" || p.hasPrefix(home + "/.Trash/")
            || p.hasPrefix(home + "/Library/Application Support/SpaceMithra/")
        let sensitiveRoots = ["/.ssh", "/.gnupg", "/.docker", "/Library/Keychains", "/Library/Mail", "/Library/Messages", "/Library/Containers", "/Library/Group Containers", "/Library/Developer/CoreSimulator", "/Library/Developer/Xcode/Archives"]
        let sensitive = sensitiveRoots.contains { p == home + $0 || p.hasPrefix(home + $0 + "/") }
        // Unrecognized Library data may be application state even without a database extension.
        let unknownLibraryState = p.lowercased().hasPrefix(home.lowercased() + "/library/") && Classifier.recognizedCache(p) == nil
        if prohibited || sensitive || unknownLibraryState || protections.contains(where: { $0.matches(p) }) {
            return Assessment(risk: .protected, explanation: "risk.protected", consequence: "consequence.protected", eligible: false)
        }
        if file.isRegular != true || file.isSymlink || file.isDirectory || file.inPackage || file.isPackage || file.identity.links > 1 || file.cloud || file.category == .cloud {
            return Assessment(risk: .protected, explanation: "risk.special", consequence: "consequence.special", eligible: false)
        }
        if ["db", "sqlite", "sqlite3", "db-wal", "db-shm", "sqlite-wal", "sqlite-shm", "sqlite3-wal", "sqlite3-shm"].contains(URL(fileURLWithPath: p).pathExtension.lowercased()) || file.category == .support {
            return Assessment(risk: .protected, explanation: "risk.database", consequence: "consequence.database", eligible: false)
        }
        if Classifier.recognizedCache(p) != nil {
            // Active use cannot be proven absent. Recognized caches always require review.
            return Assessment(risk: .reviewRequired, explanation: "risk.cache", consequence: "consequence.cache", eligible: true)
        }
        if file.modified.map({ now.timeIntervalSince($0) < 86400 }) ?? true {
            return Assessment(risk: .reviewRequired, explanation: "risk.recent", consequence: "consequence.user", eligible: true)
        }
        return Assessment(risk: .unknown, explanation: "risk.unknown", consequence: "consequence.user", eligible: true)
    }
}
