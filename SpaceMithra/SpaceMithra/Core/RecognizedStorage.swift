import Foundation

public struct StorageRule: Identifiable, Sendable {
    public let id: String
    public let owner: String
    public let group: String
    public let relativePath: String
    public let isCache: Bool
    public let mayRegenerate: Bool
    public var path: String { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(relativePath).path }
    public func matches(_ candidate: String) -> Bool { candidate == path || candidate.hasPrefix(path + "/") }
    public static let all: [StorageRule] = [
        .init(id: "safari", owner: "Safari", group: "browsers", relativePath: "Library/Caches/com.apple.Safari", isCache: true, mayRegenerate: true),
        .init(id: "chrome", owner: "Chrome", group: "browsers", relativePath: "Library/Caches/Google/Chrome", isCache: true, mayRegenerate: true),
        .init(id: "firefox", owner: "Firefox", group: "browsers", relativePath: "Library/Caches/Firefox", isCache: true, mayRegenerate: true),
        .init(id: "adobe", owner: "Adobe", group: "creative", relativePath: "Library/Caches/Adobe", isCache: true, mayRegenerate: true),
        .init(id: "premiere", owner: "Adobe Media Cache", group: "creative", relativePath: "Library/Application Support/Adobe/Common/Media Cache Files", isCache: true, mayRegenerate: true),
        .init(id: "derived", owner: "Xcode DerivedData", group: "development", relativePath: "Library/Developer/Xcode/DerivedData", isCache: true, mayRegenerate: true),
        .init(id: "archives", owner: "Xcode Archives", group: "development", relativePath: "Library/Developer/Xcode/Archives", isCache: false, mayRegenerate: false),
        .init(id: "simulators", owner: "iOS Simulators", group: "development", relativePath: "Library/Developer/CoreSimulator", isCache: false, mayRegenerate: false),
        .init(id: "npm", owner: "npm", group: "development", relativePath: ".npm/_cacache", isCache: true, mayRegenerate: true),
        .init(id: "yarn", owner: "Yarn", group: "development", relativePath: "Library/Caches/Yarn", isCache: true, mayRegenerate: true),
        .init(id: "pnpm", owner: "pnpm", group: "development", relativePath: "Library/pnpm/store", isCache: true, mayRegenerate: true),
        .init(id: "python", owner: "Python pip", group: "development", relativePath: "Library/Caches/pip", isCache: true, mayRegenerate: true),
        .init(id: "homebrew", owner: "Homebrew", group: "development", relativePath: "Library/Caches/Homebrew", isCache: true, mayRegenerate: true),
        .init(id: "docker", owner: "Docker", group: "development", relativePath: "Library/Containers/com.docker.docker", isCache: false, mayRegenerate: false),
        .init(id: "dockerHome", owner: "Docker configuration", group: "development", relativePath: ".docker", isCache: false, mayRegenerate: false)
    ]
}
public struct DiscoveredStorage: Identifiable, Sendable {
    public let rule: StorageRule
    public let bytes: Int64
    public var id: String { rule.id }
}
