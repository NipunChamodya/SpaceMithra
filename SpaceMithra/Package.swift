// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "SpaceMithra", platforms: [.macOS(.v13)], products: [.library(name: "SpaceMithraCore", targets: ["SpaceMithraCore"])], targets: [
    .target(name: "SpaceMithraCore", path: "SpaceMithra", exclude: ["App", "Features", "Localization", "Resources"], linkerSettings: [.linkedLibrary("sqlite3")]),
    .target(name: "SpaceMithraPresentation", dependencies: ["SpaceMithraCore"], path: "SpaceMithra/Features", exclude: ["MainView.swift", "FileDetail.swift", "FolderColumns.swift", "StorageMap.swift"]),
    .testTarget(name: "SpaceMithraCoreTests", dependencies: ["SpaceMithraCore", "SpaceMithraPresentation"], path: "SpaceMithraTests")
])
