import Foundation
import CoreServices

public actor ApplicationInventory {
    public init() {}
    public func discover(catalog:Catalog, roots:[URL]?=nil, home:URL=FileManager.default.homeDirectoryForCurrentUser) async throws -> [ApplicationStorage] {
        let locations=roots ?? [URL(fileURLWithPath:"/Applications",isDirectory:true),home.appendingPathComponent("Applications",isDirectory:true),URL(fileURLWithPath:"/System/Applications",isDirectory:true)]
        var apps:[String:ApplicationStorage]=[:]
        for root in locations {
            try Task.checkCancellation()
            guard let children=try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:[.isDirectoryKey,.isSymbolicLinkKey,.isPackageKey],options:[.skipsHiddenFiles]) else {continue}
            var candidates=children
            // Only one organizational folder level (for example Utilities); never walk app internals.
            for folder in children where folder.pathExtension.lowercased() != "app" {
                guard let v=try? folder.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey]),v.isDirectory == true,v.isSymbolicLink != true else {continue}
                if let nested=try? FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:[.isPackageKey],options:[.skipsHiddenFiles]) {candidates.append(contentsOf:nested)}
            }
            for input in candidates where input.pathExtension.lowercased() == "app" {
                try Task.checkCancellation()
                guard apps.count < 2000 else {break}
                // Application aliases may be inspected as metadata only; scanner/cleanup policies do not change.
                guard let original=try? FileLocation.validated(input),
                      let url=try? FileLocation.validated(original.resolvingSymlinksInPath()), let metadata=try? FileMetadata.read(url),metadata.isDirectory,metadata.isPackage,!metadata.isSymlink else {continue}
                let bundle=Bundle(url:url), identifier=bundle?.bundleIdentifier
                let name=(bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String) ?? (bundle?.infoDictionary?["CFBundleDisplayName"] as? String) ?? url.deletingPathExtension().lastPathComponent
                let record=try await catalog.record(at:url.path)
                var cacheURLs:[URL]=[],dataURLs:[URL]=[]
                var cacheTotal:Int64=0,dataTotal:Int64=0,cacheKnown=false,dataKnown=false,cacheMissing=false,dataMissing=false
                if let identifier, !identifier.isEmpty, !identifier.contains("/"), !identifier.contains("..") {
                    for (base,isCache) in [("Library/Caches",true),("Library/Application Support",false),("Library/Containers",false)] {
                        let path=home.appendingPathComponent(base,isDirectory:true).appendingPathComponent(identifier,isDirectory:true)
                        guard let related=try? FileMetadata.read(path), related.isDirectory,!related.isSymlink,FileManager.default.isReadableFile(atPath:path.path) else {continue}
                        let size=try await catalog.record(at:path.path)?.logical
                        if isCache {cacheURLs.append(path);if let size {cacheTotal += size;cacheKnown=true}else{cacheMissing=true}}
                        else {dataURLs.append(path);if let size {dataTotal += size;dataKnown=true}else{dataMissing=true}}
                    }
                }
                let lastUsed:Date?
                if let item=MDItemCreateWithURL(kCFAllocatorDefault,url as CFURL) {lastUsed=MDItemCopyAttribute(item,kMDItemLastUsedDate) as? Date}else{lastUsed=nil}
                apps[url.path]=ApplicationStorage(url:url,name:name,bundleIdentifier:identifier,bundleSize:record?.logical,cacheSize:cacheKnown && !cacheMissing ? cacheTotal:nil,relatedDataSize:dataKnown && !dataMissing ? dataTotal:nil,cacheURLs:cacheURLs,relatedDataURLs:dataURLs,lastUsed:lastUsed)
            }
        }
        return apps.values.sorted{$0.name.localizedStandardCompare($1.name) == .orderedAscending}
    }
}
