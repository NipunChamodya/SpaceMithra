import Foundation
import CryptoKit

public struct DuplicateGroup: Identifiable, Sendable {
    public let id: String
    public let files: [FileRecord]
}
public actor DuplicateDetector {
    public init() {}
    public func find(catalog: Catalog, progress: @Sendable (Int) async -> Void) async throws -> [DuplicateGroup] {
        // Disk catalog is paged; candidate groups are bounded to avoid unbounded hash work.
        var offset = 0, count = 0
        var candidates: [Int64: [FileRecord]] = [:]
        while true {
            try Task.checkCancellation()
            let page = try await catalog.list(biggest: true, offset: offset, limit: 500)
            if page.isEmpty { break }
            for file in page where file.logical > 0 && !file.isSymlink && !file.inPackage && !file.cloud && file.identity.links == 1 {
                candidates[file.logical, default: []].append(file)
                count += 1
                if count > 20000 { throw StorageError.refused("error.duplicateLimit") }
            }
            offset += page.count
        }
        var result: [DuplicateGroup] = [], processed = 0
        for group in candidates.values where group.count > 1 {
            var hashes: [String: [FileRecord]] = [:]
            for file in group {
                try Task.checkCancellation()
                guard URL(fileURLWithPath: file.path).resolvingSymlinksInPath().path == file.path,
                      try FileMetadata.identity(file.path) == file.identity else { continue }
                let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: file.path))
                var hasher = SHA256()
                do {
                    while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
                        try Task.checkCancellation(); hasher.update(data: data)
                    }
                    try handle.close()
                } catch { try? handle.close(); throw error }
                guard try FileMetadata.identity(file.path) == file.identity else { continue }
                let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
                hashes[digest, default: []].append(file)
                processed += 1; await progress(processed)
            }
            for (hash, files) in hashes where files.count > 1 {
                // Full cryptographic content equality; no automatic copy selection.
                result.append(DuplicateGroup(id: hash, files: files))
            }
        }
        return result.sorted { ($0.files.first?.logical ?? 0) > ($1.files.first?.logical ?? 0) }
    }
}
