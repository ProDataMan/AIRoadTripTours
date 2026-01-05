import Foundation
import AIRoadTripToursCore

/// Service for enriching POI data with additional information from Google Places API.
@available(iOS 17.0, macOS 14.0, *)
public actor POIEnrichmentService {

    public init() {}

    /// Enriches a POI with description and other details from Google Places.
    ///
    /// - Parameter poi: The POI to enrich
    /// - Returns: An enriched POI with description and other details, or the original POI if enrichment fails
    public func enrich(_ poi: POI) async -> POI {
        // Skip if already has description or Google Places not configured
        guard poi.description == nil || poi.description?.isEmpty == true else {
            return poi
        }

        guard ServiceConfiguration.isGooglePlacesConfigured else {
            return poi
        }

        do {
            // Search for the place
            guard let placeId = try await searchGooglePlace(poi: poi) else {
                return poi
            }

            // Fetch place details including description
            guard let details = try await fetchPlaceDetails(placeId: placeId) else {
                return poi
            }

            // Create enriched POI with description and updated details
            return POI(
                id: poi.id,
                name: poi.name,
                description: details.description,
                category: poi.category,
                location: poi.location,
                contact: details.contact ?? poi.contact,
                hours: details.hours ?? poi.hours,
                rating: details.rating ?? poi.rating,
                source: poi.source,
                tags: poi.tags,
                createdAt: poi.createdAt,
                updatedAt: Date()
            )

        } catch {
            print("⚠️ Failed to enrich POI \(poi.name): \(error)")
            return poi
        }
    }

    /// Enriches multiple POIs in parallel.
    ///
    /// - Parameter pois: Array of POIs to enrich
    /// - Returns: Array of enriched POIs
    public func enrichBatch(_ pois: [POI]) async -> [POI] {
        await withTaskGroup(of: POI.self) { group in
            for poi in pois {
                group.addTask {
                    await self.enrich(poi)
                }
            }

            var enriched: [POI] = []
            for await poi in group {
                enriched.append(poi)
            }
            return enriched
        }
    }

    // MARK: - Google Places API

    private func searchGooglePlace(poi: POI) async throws -> String? {
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
            throw POIEnrichmentError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw POIEnrichmentError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let results = json?["results"] as? [[String: Any]],
              let firstResult = results.first,
              let placeId = firstResult["place_id"] as? String else {
            return nil
        }

        return placeId
    }

    private func fetchPlaceDetails(placeId: String) async throws -> PlaceDetails? {
        let apiKey = ServiceConfiguration.googlePlacesAPIKey

        let urlString = """
        https://maps.googleapis.com/maps/api/place/details/json?\
        place_id=\(placeId)&\
        fields=editorial_summary,formatted_address,formatted_phone_number,website,rating,user_ratings_total,price_level,opening_hours&\
        key=\(apiKey)
        """

        guard let url = URL(string: urlString) else {
            throw POIEnrichmentError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw POIEnrichmentError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let result = json?["result"] as? [String: Any] else {
            return nil
        }

        // Extract description from editorial_summary
        let description: String?
        if let editorialSummary = result["editorial_summary"] as? [String: Any],
           let overview = editorialSummary["overview"] as? String {
            description = overview
        } else {
            description = nil
        }

        // Extract contact information
        let phone = result["formatted_phone_number"] as? String
        let website = result["website"] as? String
        let contact = (phone != nil || website != nil) ? POIContact(phone: phone, website: website) : nil

        // Extract rating information
        let rating: POIRating?
        if let averageRating = result["rating"] as? Double,
           let totalRatings = result["user_ratings_total"] as? Int {
            let priceLevel = result["price_level"] as? Int
            rating = POIRating(averageRating: averageRating, totalRatings: totalRatings, priceLevel: priceLevel)
        } else {
            rating = nil
        }

        // Extract hours
        let hours: POIHours?
        if let openingHours = result["opening_hours"] as? [String: Any] {
            let isOpenNow = openingHours["open_now"] as? Bool
            if let weekdayText = openingHours["weekday_text"] as? [String],
               !weekdayText.isEmpty {
                hours = POIHours(description: weekdayText.joined(separator: ", "), isOpenNow: isOpenNow)
            } else {
                hours = nil
            }
        } else {
            hours = nil
        }

        return PlaceDetails(
            description: description,
            contact: contact,
            rating: rating,
            hours: hours
        )
    }
}

// MARK: - Supporting Types

private struct PlaceDetails {
    let description: String?
    let contact: POIContact?
    let rating: POIRating?
    let hours: POIHours?
}

public enum POIEnrichmentError: Error, LocalizedError {
    case invalidURL
    case apiError(String)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for Google Places API"
        case .apiError(let message):
            return "Google Places API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
