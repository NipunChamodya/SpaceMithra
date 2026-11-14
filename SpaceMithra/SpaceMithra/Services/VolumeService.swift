import Foundation

public struct StorageVolume: Identifiable, Sendable {
    public let id: String
    public let url: URL
    public let name: String
    public let isStartup: Bool
    public let isInternal: Bool
}
public struct DiskCapacitySnapshot: Sendable {
    public let name: String
    public let volumeURL: URL
    public let total: Int64
    public let available: Int64
    public let availableForImportantUse: Int64?
    public let date: Date
    public var used: Int64 { total - available }
    // These are intentionally unavailable: Foundation does not attribute these bytes.
    public var purgeable: Int64? { nil }
    public var snapshots: Int64? { nil }
    public init(name: String, volumeURL: URL, total: Int64, available: Int64, availableForImportantUse: Int64? = nil, date: Date = Date()) throws {
        guard total > 0, available >= 0, available <= total else { throw StorageError.refused("error.capacity") }
        self.name = name; self.volumeURL = volumeURL; self.total = total; self.available = available
        self.availableForImportantUse = availableForImportantUse; self.date = date
    }
}
public actor VolumeService {
    public init() {}
    public func startupCapacity() throws -> DiskCapacitySnapshot { try capacity(at: URL(fileURLWithPath: "/", isDirectory: true)) }
    public func capacity(at input: URL) throws -> DiskCapacitySnapshot {
        let url = try FileLocation.validated(input)
        let values = try url.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeURLKey])
        guard let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity else { throw StorageError.refused("error.capacity") }
        let volumeURL = try FileLocation.validated((values.allValues[.volumeURLKey] as? URL) ?? url)
        return try DiskCapacitySnapshot(name: values.volumeName ?? url.lastPathComponent, volumeURL: volumeURL,
                                        total: Int64(total), available: Int64(available), availableForImportantUse: values.volumeAvailableCapacityForImportantUsage)
    }
    public func discover() -> [StorageVolume] {
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let urls = [root] + (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey,.volumeUUIDStringKey,.volumeIsInternalKey], options: [.skipHiddenVolumes]) ?? [])
        var seen: Set<String> = [], result: [StorageVolume] = []
        for input in urls {
            guard let url = try? FileLocation.validated(input), !url.path.hasPrefix("/System/Volumes/") else { continue }
            guard let v = try? url.resourceValues(forKeys: [.volumeNameKey,.volumeUUIDStringKey,.volumeIsInternalKey]) else { continue }
            let id = v.volumeUUIDString ?? url.path
            guard seen.insert(id).inserted else { continue }
            result.append(StorageVolume(id: id, url: url, name: v.volumeName ?? url.lastPathComponent, isStartup: url.path == "/", isInternal: v.volumeIsInternal ?? false))
        }
        return result
    }
}
public struct ScanStorageSummary: Sendable {
    public var logical: Int64 = 0
    public var allocatedKnown: Int64 = 0
    public var categoryBytes: [FileCategory: Int64] = [:]
    public var systemLogical: Int64 = 0
    public var fileCount: Int = 0
    public init() {}
}


public struct DiskScanAccounting:Sendable {
    public let scannedAllocationEstimate:Int64?
    public let unattributedUsedEstimate:Int64?
    public init(disk:DiskCapacitySnapshot,allocatedKnown:Int64?,sameStartupStorage:Bool) {
        if sameStartupStorage,let allocatedKnown,allocatedKnown>=0,allocatedKnown<=disk.used {
            scannedAllocationEstimate=allocatedKnown;unattributedUsedEstimate=disk.used-allocatedKnown
        } else if allocatedKnown == nil || !sameStartupStorage {
            scannedAllocationEstimate=nil;unattributedUsedEstimate=disk.used
        } else {scannedAllocationEstimate=nil;unattributedUsedEstimate=nil}
    }
}
