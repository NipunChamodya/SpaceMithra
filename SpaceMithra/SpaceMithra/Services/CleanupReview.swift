import Foundation

public struct CleanupReviewItem: Identifiable, Sendable {
    public var id: String { record.path }
    public let record: FileRecord
    public let assessment: Assessment
    /// nil means preflight found no blocker, not a guarantee that Trash will succeed.
    public let blocker: String?
}
public struct CleanupReview: Identifiable, Sendable {
    public let id = UUID()
    public let date = Date()
    public let items: [CleanupReviewItem]
    public var records: [FileRecord] { items.map(\.record) }
    public var readyCount: Int { items.filter { $0.blocker == nil }.count }
    public var blockedCount: Int { items.count - readyCount }
    public var estimatedSelectedBytes: Int64 {
        items.reduce(0) { total, item in
            let (sum, overflow) = total.addingReportingOverflow(max(0, item.record.logical))
            return overflow ? Int64.max : sum
        }
    }
    public var canConfirm: Bool { !items.isEmpty && blockedCount == 0 }
}

/// Preflight never modifies selected files or approves fresh identities automatically.
/// The cleanup engine still revalidates every record after explicit confirmation.
public actor CleanupReviewer {
    public init() {}
    public func review(_ records: [FileRecord], journal: any CleanupJournal) async throws -> CleanupReview {
        let rules = try await journal.protections()
        try Task.checkCancellation()
        _ = try await journal.duplicateKeepers(for: records)
        var items: [CleanupReviewItem] = []
        for record in records {
            try Task.checkCancellation()
            let assessment = RiskEngine.assess(record, protections: rules)
            var blocker: String?
            do {
                guard assessment.eligible else { throw StorageError.refused("error.protected") }
                let url = URL(fileURLWithPath: record.path)
                guard url.standardizedFileURL.path == record.path,
                      url.resolvingSymlinksInPath().path == record.path else { throw StorageError.refused("error.symlink") }
                let fresh = try FileMetadata.read(url)
                guard fresh.identity == record.identity else { throw StorageError.refused("error.changed") }
                guard RiskEngine.assess(fresh, protections: rules).eligible else { throw StorageError.refused("error.protected") }
                guard FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path) else { throw StorageError.refused("error.permission") }
            } catch { blocker = error.localizedDescription }
            items.append(CleanupReviewItem(record: record, assessment: assessment, blocker: blocker))
        }
        try Task.checkCancellation()
        return CleanupReview(items: items)
    }
}

public struct CleanupHistorySession: Identifiable, Sendable {
    public let id: String
    public let entries: [HistoryEntry]
    public var date: Date { entries.map(\.date).max() ?? .distantPast }
    public var counts: [String: Int] { Dictionary(grouping: entries, by: \.status).mapValues(\.count) }
    public var estimatedSelectedBytes: Int64 {
        entries.reduce(0) { total, entry in
            let (sum, overflow) = total.addingReportingOverflow(max(0, entry.record.logical))
            return overflow ? Int64.max : sum
        }
    }
    public static func group(_ entries: [HistoryEntry]) -> [CleanupHistorySession] {
        Dictionary(grouping: entries, by: \.session).map { id, entries in
            CleanupHistorySession(id: id, entries: entries.sorted { $0.date > $1.date })
        }.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date }
    }
}
