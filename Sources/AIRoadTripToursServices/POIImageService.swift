import Foundation
import AIRoadTripToursCore

/// Service for fetching images for Points of Interest from Wikipedia Commons and Google Maps.
@available(iOS 17.0, macOS 14.0, *)
public actor POIImageService {

    private let urlSession: URLSession
    private let imageCache: NSCache<NSString, NSArray>

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.imageCache = NSCache()
        self.imageCache.countLimit = 100
    }

    /// Fetches images for a POI from Wikipedia Commons, falling back to Google Places if needed.
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

        // Try Wikipedia Commons first
        var images = try await fetchFromWikipedia(poi: poi, limit: limit)

        // If Wikipedia returns no images, try Google Places
        if images.isEmpty {
            print("📷 No Wikipedia images found for \(poi.name), trying Google Places...")
            images = try await fetchFromGooglePlaces(poi: poi, limit: limit)
        }

        // Cache results
        if !images.isEmpty {
            imageCache.setObject(images as NSArray, forKey: cacheKey)
        }

        return images
    }

    // MARK: - Wikipedia Commons

    private func fetchFromWikipedia(poi: POI, limit: Int) async throws -> [POIImage] {
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

        return try parseWikimediaResponse(data)
    }

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

    // MARK: - Google Places

    private func fetchFromGooglePlaces(poi: POI, limit: Int) async throws -> [POIImage] {
        // First, search for the place to get the place ID
        guard let placeId = try await searchGooglePlace(poi: poi) else {
            print("📷 No Google Place found for \(poi.name)")
            return []
        }

        // Then fetch photos for that place
        return try await fetchGooglePlacePhotos(placeId: placeId, limit: limit)
    }

    private func searchGooglePlace(poi: POI) async throws -> String? {
        // Skip if Google Places API is not configured
        guard ServiceConfiguration.isGooglePlacesConfigured else {
            print("⚠️ Google Places API key not configured, skipping Google image search")
            return nil
        }

        // Build search query with name and location
        let searchTerm = poi.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? poi.name

        let apiKey = ServiceConfiguration.googlePlacesAPIKey

        let urlString = """
        https://maps.googleapis.com/maps/api/place/textsearch/json?\
        query=\(searchTerm)&\
        location=\(poi.location.latitude),\(poi.location.longitude)&\
        radius=1000&\
        key=\(apiKey)
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

        // Parse response to get place_id
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let firstResult = results.first,
              let placeId = firstResult["place_id"] as? String else {
            return nil
        }

        return placeId
    }

    private func fetchGooglePlacePhotos(placeId: String, limit: Int) async throws -> [POIImage] {
        let apiKey = ServiceConfiguration.googlePlacesAPIKey

        let urlString = """
        https://maps.googleapis.com/maps/api/place/details/json?\
        place_id=\(placeId)&\
        fields=photos&\
        key=\(apiKey)
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

        // Parse photos
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let photos = result["photos"] as? [[String: Any]] else {
            return []
        }

        var images: [POIImage] = []

        for photo in photos.prefix(limit) {
            guard let photoReference = photo["photo_reference"] as? String else {
                continue
            }

            // Build photo URL
            let photoURL = """
            https://maps.googleapis.com/maps/api/place/photo?\
            maxwidth=800&\
            photo_reference=\(photoReference)&\
            key=\(apiKey)
            """

            let thumbnailURL = """
            https://maps.googleapis.com/maps/api/place/photo?\
            maxwidth=400&\
            photo_reference=\(photoReference)&\
            key=\(apiKey)
            """

            // Extract attributions
            let attributions = (photo["html_attributions"] as? [String])?.joined(separator: ", ")

            let poiImage = POIImage(
                url: photoURL,
                thumbnailURL: thumbnailURL,
                caption: nil,
                attribution: attributions,
                source: "google"
            )

            images.append(poiImage)
        }

        print("📷 Found \(images.count) Google Places images for place ID: \(placeId)")
        return images
    }

    // MARK: - Helpers

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
