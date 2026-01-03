import Foundation
import MapKit
import AIRoadTripToursCore

/// MapKit-based POI discovery service using live Apple Maps data.
@available(iOS 17.0, macOS 14.0, *)
public actor MapKitPOIService: POIRepository {

    public init() {}

    public func findAll() async throws -> [POI] {
        // Not supported for MapKit - use findNearby instead
        throw POIServiceError.operationNotSupported("findAll not supported for live MapKit data. Use findNearby instead.")
    }

    public func find(matching filter: POIFilter) async throws -> [POI] {
        guard let location = filter.location, let radius = filter.radiusMiles else {
            throw POIServiceError.invalidParameters("Location and radius required for MapKit search")
        }

        return try await findNearby(
            location: location,
            radiusMiles: radius,
            categories: filter.categories
        )
    }

    public func find(id: UUID) async throws -> POI? {
        // Not supported for MapKit
        throw POIServiceError.operationNotSupported("Find by ID not supported for live MapKit data")
    }

    public func save(_ poi: POI) async throws -> POI {
        // Not supported for MapKit (read-only)
        throw POIServiceError.operationNotSupported("Save not supported for live MapKit data")
    }

    public func delete(id: UUID) async throws {
        // Not supported for MapKit (read-only)
        throw POIServiceError.operationNotSupported("Delete not supported for live MapKit data")
    }

    public func findNearby(
        location: GeoLocation,
        radiusMiles: Double,
        categories: Set<POICategory>?
    ) async throws -> [POI] {
        var allPOIs: [POI] = []

        // If categories specified, search for each category
        if let categories = categories {
            for category in categories {
                let pois = try await searchMapKit(
                    location: location,
                    radiusMiles: radiusMiles,
                    category: category
                )
                allPOIs.append(contentsOf: pois)
            }
        } else {
            // Search for common categories
            let commonCategories: [POICategory] = [
                .attraction, .restaurant, .cafe, .park, .museum,
                .historicSite, .scenic, .evCharger
            ]

            for category in commonCategories {
                let pois = try await searchMapKit(
                    location: location,
                    radiusMiles: radiusMiles,
                    category: category
                )
                allPOIs.append(contentsOf: pois)
            }
        }

        // Remove duplicates based on location proximity (within 50 meters)
        return removeDuplicates(allPOIs)
    }

    private func searchMapKit(
        location: GeoLocation,
        radiusMiles: Double,
        category: POICategory
    ) async throws -> [POI] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = mapSearchQuery(for: category)
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            latitudinalMeters: radiusMiles * 1609.34, // miles to meters
            longitudinalMeters: radiusMiles * 1609.34
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        return response.mapItems.compactMap { mapItem in
            convertMapItemToPOI(mapItem, category: category, searchLocation: location, radiusMiles: radiusMiles)
        }
    }

    private func mapSearchQuery(for category: POICategory) -> String {
        switch category {
        case .restaurant: return "restaurant"
        case .cafe: return "cafe coffee"
        case .attraction: return "tourist attraction"
        case .park: return "park"
        case .museum: return "museum"
        case .historicSite: return "historic site landmark"
        case .scenic: return "scenic viewpoint"
        case .hiking: return "hiking trail trailhead"
        case .beach: return "beach"
        case .lake: return "lake"
        case .waterfall: return "waterfall"
        case .evCharger: return "electric vehicle charging station"
        case .hotel: return "hotel"
        case .shopping: return "shopping mall store"
        case .entertainment: return "entertainment venue"
        }
    }

    private func convertMapItemToPOI(
        _ mapItem: MKMapItem,
        category: POICategory,
        searchLocation: GeoLocation,
        radiusMiles: Double
    ) -> POI? {
        guard let name = mapItem.name else { return nil }

        let location = GeoLocation(
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude,
            address: formatAddress(mapItem.placemark)
        )

        // Filter out items outside the radius
        guard location.distance(to: searchLocation) <= radiusMiles else {
            return nil
        }

        let contact = POIContact(
            phone: mapItem.phoneNumber,
            website: mapItem.url?.absoluteString,
            email: nil
        )

        return POI(
            name: name,
            description: nil, // MapKit doesn't provide descriptions
            category: category,
            location: location,
            contact: contact.phone != nil || contact.website != nil ? contact : nil,
            hours: nil, // Could add hours parsing if needed
            rating: nil, // MapKit doesn't provide ratings
            source: .google, // Maps data comes from various sources
            tags: []
        )
    }

    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        var components: [String] = []

        if let street = placemark.thoroughfare {
            if let number = placemark.subThoroughfare {
                components.append("\(number) \(street)")
            } else {
                components.append(street)
            }
        }

        if let city = placemark.locality {
            components.append(city)
        }

        if let state = placemark.administrativeArea {
            components.append(state)
        }

        if let zip = placemark.postalCode {
            components.append(zip)
        }

        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

    private func removeDuplicates(_ pois: [POI]) -> [POI] {
        var unique: [POI] = []

        for poi in pois {
            let isDuplicate = unique.contains { existing in
                // Consider duplicates if within 50 meters and same name
                existing.location.distance(to: poi.location) < 0.031 && // 50 meters in miles
                existing.name.lowercased() == poi.name.lowercased()
            }

            if !isDuplicate {
                unique.append(poi)
            }
        }

        return unique
    }
}

public enum POIServiceError: Error, LocalizedError {
    case operationNotSupported(String)
    case invalidParameters(String)
    case searchFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .operationNotSupported(let message):
            return "Operation not supported: \(message)"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        case .searchFailed(let error):
            return "Search failed: \(error.localizedDescription)"
        }
    }
}
