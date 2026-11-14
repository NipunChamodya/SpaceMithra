import Foundation

/// Reconstruct file URLs instead of inheriting mounted-root URL parent semantics.
public enum FileLocation {
    public static func fileURL(path: String, isDirectory: Bool = true) throws -> URL {
        guard path.hasPrefix("/"), !path.contains("\0") else { throw StorageError.refused("error.invalidLocation") }
        return try validated(URL(fileURLWithPath: path, isDirectory: isDirectory))
    }
    public static func validated(_ url: URL) throws -> URL {
        guard url.isFileURL, url.host == nil || url.host == "" || url.host == "localhost",
              url.query == nil, url.fragment == nil, url.path.hasPrefix("/"),
              !url.path.contains("\0"), !url.absoluteString.lowercased().contains("%00") else { throw StorageError.refused("error.invalidLocation") }
        // Foundation standardization can rewrite /private/var to the /var symlink.
        // Normalize dot components lexically without changing filesystem identity.
        let components=url.pathComponents
        let normalized:String
        if components.contains(".") || components.contains("..") || url.path.contains("//") {
            var location=URL(fileURLWithPath:"/",isDirectory:true)
            for component in components where component != "/" && component != "." {
                if component == ".." {if location.path != "/" {location.deleteLastPathComponent()}}
                else {location.appendPathComponent(component,isDirectory:true)}
            }
            normalized=location.path
        } else {normalized=url.path}
        return URL(fileURLWithPath: normalized, isDirectory: normalized == "/" || url.hasDirectoryPath)
    }
    public static func contains(_ child: String, within root: String) -> Bool {
        child == root || (root == "/" ? child.hasPrefix("/") : child.hasPrefix(root + "/"))
    }
    public static func parent(of url: URL, within boundary: URL) throws -> URL? {
        let current = try validated(url), root = try validated(boundary)
        guard contains(current.path, within: root.path) else { throw StorageError.refused("error.invalidLocation") }
        guard current.path != root.path else { return nil }
        let parent = try validated(URL(fileURLWithPath: current.path, isDirectory: true).deletingLastPathComponent())
        return contains(parent.path, within: root.path) ? parent : nil
    }
    public static func breadcrumbs(to url: URL, within boundary: URL) throws -> [URL] {
        var current = try validated(url)
        let root = try validated(boundary)
        guard contains(current.path, within: root.path) else { throw StorageError.refused("error.invalidLocation") }
        var result = [current]
        while let next = try parent(of: current, within: root) { result.insert(next, at: 0); current = next }
        return result
    }
}
