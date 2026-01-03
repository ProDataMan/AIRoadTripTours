import Foundation

/// Image associated with a POI.
public struct POIImage: Codable, Sendable, Identifiable {
    public let id: UUID
    public let url: String
    public let thumbnailURL: String?
    public let caption: String?
    public let attribution: String?
    public let source: String // "wikipedia", "unsplash", "local"

    public init(
        id: UUID = UUID(),
        url: String,
        thumbnailURL: String? = nil,
        caption: String? = nil,
        attribution: String? = nil,
        source: String = "wikipedia"
    ) {
        self.id = id
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.caption = caption
        self.attribution = attribution
        self.source = source
    }
}
