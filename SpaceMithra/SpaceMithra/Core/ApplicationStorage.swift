import Foundation

public struct ApplicationStorage: Identifiable, Sendable {
    public var id:String {url.path}
    public let url:URL
    public let name:String
    public let bundleIdentifier:String?
    public let bundleSize:Int64?
    public let cacheSize:Int64?
    public let relatedDataSize:Int64?
    public let cacheURLs:[URL]
    public let relatedDataURLs:[URL]
    public let lastUsed:Date?
}
