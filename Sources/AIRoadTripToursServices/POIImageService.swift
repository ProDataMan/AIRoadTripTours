import Foundation
import AIRoadTripToursCore

/// Service for fetching images for Points of Interest from Wikipedia Commons.
@available(iOS 17.0, macOS 14.0, *)
public actor POIImageService {

    private let urlSession: URLSession
    private let imageCache: NSCache<NSString, NSArray>

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.imageCache = NSCache()
        self.imageCache.countLimit = 100
    }

    /// Fetches images for a POI from Wikipedia Commons.
    /// - Parameters:
    ///   - poi: The point of interest to fetch images for
    ///   - limit: Maximum number of images to fetch (default: 10)
    /// - Returns: Array of POIImage objects
    public func fetchImages(for poi: POI, limit: Int = 10) async throws -> [POIImage] {
        // Check cache first
        let cacheKey = "\(poi.id.uuidString)" as NSString
        if let cached = imageCache.object(forKey: cacheKey) as? [POIImage] {
            return cached
        }

        // Build search query from POI name
        let searchTerm = poi.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? poi.name

        // Wikipedia Commons API endpoint
        let urlString = """
        https://commons.wikimedia.org/w/api.php?\
        action=query&\
        generator=search&\
        gsrsearch=\(searchTerm)&\
        gsrnamespace=6&\
        gsrlimit=\(limit)&\
        prop=imageinfo&\
        iiprop=url|extmetadata&\
        format=json
        """

        guard let url = URL(string: urlString) else {
            throw ImageServiceError.invalidURL
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ImageServiceError.httpError(statusCode: httpResponse.statusCode)
        }

        let images = try parseWikimediaResponse(data)

        // Cache results
        imageCache.setObject(images as NSArray, forKey: cacheKey)

        return images
    }

    // MARK: - Private

    private nonisolated func parseWikimediaResponse(_ data: Data) throws -> [POIImage] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = json["query"] as? [String: Any],
              let pages = query["pages"] as? [String: Any] else {
            return []
        }

        var images: [POIImage] = []

        for (_, pageData) in pages {
            guard let page = pageData as? [String: Any],
                  let imageInfo = page["imageinfo"] as? [[String: Any]],
                  let firstImage = imageInfo.first else {
                continue
            }

            // Extract URL
            guard let urlString = firstImage["url"] as? String else {
                continue
            }

            // Extract thumbnail URL (use 800px width for thumbnails)
            let thumbnailURL = firstImage["thumburl"] as? String

            // Extract metadata
            let extMetadata = firstImage["extmetadata"] as? [String: Any]
            let caption = extractMetadataValue(from: extMetadata, key: "ImageDescription")
            let attribution = extractMetadataValue(from: extMetadata, key: "Artist")
                ?? extractMetadataValue(from: extMetadata, key: "Credit")

            let poiImage = POIImage(
                url: urlString,
                thumbnailURL: thumbnailURL,
                caption: caption,
                attribution: attribution,
                source: "wikipedia"
            )

            images.append(poiImage)
        }

        return images
    }

    private nonisolated func extractMetadataValue(from metadata: [String: Any]?, key: String) -> String? {
        guard let metadata = metadata,
              let field = metadata[key] as? [String: Any],
              let value = field["value"] as? String else {
            return nil
        }

        // Strip HTML tags from value
        return value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    /// Clears the image cache.
    public func clearCache() {
        imageCache.removeAllObjects()
    }
}

/// Errors that can occur during image fetching
public enum ImageServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for image fetch"
        case .invalidResponse:
            return "Invalid response from image service"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError:
            return "Failed to decode image data"
        }
    }
}
