// swift-tools-version: 6.0
import PackageDescription
import Foundation
let featureDirectory = URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("SpaceMithra/Features")
let presentationExclusions = (try? FileManager.default.contentsOfDirectory(atPath:featureDirectory.path))?.filter { $0 != "AppModel.swift" } ?? []
let package = Package(name: "SpaceMithra", platforms: [.macOS(.v13)], products: [.library(name: "SpaceMithraCore", targets: ["SpaceMithraCore"])], targets: [
    .target(name: "SpaceMithraCore", path: "SpaceMithra", exclude: ["App", "Features", "Localization", "Resources"], linkerSettings: [.linkedLibrary("sqlite3")]),
    .target(name: "SpaceMithraPresentation", dependencies: ["SpaceMithraCore"], path: "SpaceMithra/Features", exclude: presentationExclusions),
    .testTarget(name: "SpaceMithraCoreTests", dependencies: ["SpaceMithraCore", "SpaceMithraPresentation"], path: "SpaceMithraTests")
])
