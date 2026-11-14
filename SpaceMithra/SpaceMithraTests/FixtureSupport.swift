import Foundation
import XCTest
@testable import SpaceMithraCore

struct Fixture: Sendable {
    let root: URL
    let catalog: Catalog
    init() throws {
        // All mutating tests require this explicit flag and a repository-local fixture root.
        guard ProcessInfo.processInfo.environment["SPACEMITHRA_TEST_MODE"] == "1" else {
            throw XCTSkip("Set SPACEMITHRA_TEST_MODE=1 to enable isolated filesystem fixtures")
        }
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        root = repository.appendingPathComponent(".test-fixtures/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        catalog = try Catalog(url: root.appendingPathComponent("catalog/db.sqlite"))
    }
    func file(_ name: String, content: String = "fixture data") throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
        return url
    }
    func cleanup() { try? FileManager.default.removeItem(at: root) }
}
struct FixtureTrash: TrashOperations {
    let root: URL
    var fail = false
    func trash(_ url: URL) throws -> URL {
        guard url.path.hasPrefix(root.path + "/"), root.path.contains("/.test-fixtures/"), !fail else { throw StorageError.refused("Fixture Trash failure") }
        let trash = root.appendingPathComponent("fixture-trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let destination = trash.appendingPathComponent(UUID().uuidString)
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }
    func restore(_ source: URL, to destination: URL) throws {
        guard source.path.hasPrefix(root.path + "/"), destination.path.hasPrefix(root.path + "/") else { throw StorageError.refused("Outside fixture") }
        try FileManager.default.moveItem(at: source, to: destination)
    }
}
