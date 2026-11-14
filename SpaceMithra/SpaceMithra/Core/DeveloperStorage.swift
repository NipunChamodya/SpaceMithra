import Foundation

public enum DeveloperStorageKind: String, CaseIterable, Sendable {
    case cache, dependencyStore, environment, installation, buildArtifact, projectSource, userData
}
public struct DeveloperLocation: Identifiable, Sendable {
    public let id: String
    public let tool: String
    public let icon: String
    public let relativePath: String
    public let kind: DeveloperStorageKind
    public let inspectCommand: String?
    public let absolute: Bool
    public init(_ id: String, _ tool: String, _ icon: String, _ path: String, _ kind: DeveloperStorageKind, _ command: String? = nil, absolute: Bool = false) {
        self.id=id; self.tool=tool; self.icon=icon; relativePath=path; self.kind=kind; inspectCommand=command; self.absolute=absolute
    }
    public func url(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        absolute ? URL(fileURLWithPath:relativePath,isDirectory:true) : home.appendingPathComponent(relativePath,isDirectory:true)
    }
    public static let definitions: [DeveloperLocation] = [
        .init("npm","Node.js / npm","shippingbox",".npm/_cacache",.cache,"npm config get cache"),
        .init("yarn","Yarn","shippingbox","Library/Caches/Yarn",.cache,"yarn cache dir"),
        .init("yarnBerry","Yarn","shippingbox",".yarn/berry/cache",.dependencyStore),
        .init("pnpm","pnpm","shippingbox","Library/pnpm/store",.dependencyStore,"pnpm store path"),
        .init("pnpmAlt","pnpm","shippingbox",".local/share/pnpm/store",.dependencyStore,"pnpm store path"),
        .init("nvm","Node.js / nvm","terminal",".nvm",.installation),
        .init("fnm","Node.js / fnm","terminal","Library/Application Support/fnm",.installation),
        .init("volta","Node.js / Volta","terminal",".volta",.installation,"volta list"),
        .init("nodeHeaders","Node.js","terminal","Library/Caches/node-gyp",.cache),
        .init("pip","Python / pip","terminal","Library/Caches/pip",.cache,"python3 -m pip cache info"),
        .init("pipAlt","Python / pip","terminal",".cache/pip",.cache,"python3 -m pip cache info"),
        .init("poetry","Python / Poetry","terminal","Library/Caches/pypoetry",.dependencyStore,"poetry cache list"),
        .init("poetryAlt","Python / Poetry","terminal",".cache/pypoetry",.dependencyStore,"poetry cache list"),
        .init("uv","Python / uv","terminal",".cache/uv",.cache,"uv cache dir"),
        .init("uvMac","Python / uv","terminal","Library/Caches/uv",.cache,"uv cache dir"),
        .init("pyenv","Python / pyenv","terminal",".pyenv/versions",.installation,"pyenv versions"),
        .init("conda","Conda","terminal",".conda/envs",.environment,"conda env list"),
        .init("miniconda","Conda","terminal","miniconda3/envs",.environment,"conda env list"),
        .init("anaconda","Conda","terminal","anaconda3/envs",.environment,"conda env list"),
        .init("xcodeDerived","Xcode","hammer","Library/Developer/Xcode/DerivedData",.cache),
        .init("xcodeArchives","Xcode","hammer","Library/Developer/Xcode/Archives",.userData),
        .init("simulators","Xcode / Simulator","iphone","Library/Developer/CoreSimulator",.environment,"xcrun simctl list"),
        .init("deviceSupport","Xcode / iOS","iphone","Library/Developer/Xcode/iOS DeviceSupport",.installation),
        .init("brew","Homebrew","shippingbox","Library/Caches/Homebrew",.cache,"brew cleanup --dry-run"),
        .init("brewInstall","Homebrew","shippingbox","/opt/homebrew",.installation,"brew list",absolute:true),
        .init("brewIntel","Homebrew","shippingbox","/usr/local/Homebrew",.installation,"brew list",absolute:true),
        .init("docker","Docker","shippingbox","Library/Containers/com.docker.docker",.userData,"docker system df"),
        .init("dockerHome","Docker","shippingbox",".docker",.userData,"docker system df"),
        .init("gradle","Gradle","shippingbox",".gradle/caches",.cache,"gradle --status"),
        .init("maven","Maven","shippingbox",".m2/repository",.dependencyStore),
        .init("cargoRegistry","Rust Cargo","shippingbox",".cargo/registry",.dependencyStore),
        .init("cargoGit","Rust Cargo","shippingbox",".cargo/git",.dependencyStore),
        .init("rustup","Rust toolchains","terminal",".rustup/toolchains",.installation,"rustup toolchain list"),
        .init("goBuild","Go","terminal","Library/Caches/go-build",.cache,"go env GOCACHE"),
        .init("goAlt","Go","terminal",".cache/go-build",.cache,"go env GOCACHE"),
        .init("goModules","Go","terminal","go/pkg/mod",.dependencyStore,"go env GOMODCACHE"),
        .init("dart","Flutter / Dart","terminal",".pub-cache",.dependencyStore,"dart --version"),
        .init("fvm","Flutter versions","terminal",".fvm",.installation)
    ]
    private static let resolved = definitions.map { ($0, $0.url().path) }.sorted { $0.1.count > $1.1.count }
    public static func matching(_ path: String) -> DeveloperLocation? {
        resolved.first { FileLocation.contains(path,within:$0.1) }?.0
    }
}
public struct DeveloperStorageEntry: Identifiable, Sendable {
    public var id: String { url.path }
    public let tool: String
    public let icon: String
    public let url: URL
    public let kind: DeveloperStorageKind
    public let logicalSize: Int64?
    public let inspectCommand: String?
    public var canReviewCache: Bool { kind == .cache }
}
