import Foundation

/// Criteria for filtering points of interest.
public struct POIFilter: Sendable {
    /// Filter by categories.
    public let categories: Set<POICategory>?

    /// Filter by user interests.
    public let interests: Set<UserInterest>?

    /// Filter by location within radius.
    public let location: GeoLocation?

    /// Maximum distance from location in miles.
    public let radiusMiles: Double?

    /// Minimum rating (0.0 to 5.0).
    public let minimumRating: Double?

    /// Maximum price level (1-4).
    public let maximumPriceLevel: Int?

    /// Filter by tags.
    public let tags: Set<String>?

    /// Filter by source.
    public let sources: Set<POISource>?

    public init(
        categories: Set<POICategory>? = nil,
        interests: Set<UserInterest>? = nil,
        location: GeoLocation? = nil,
        radiusMiles: Double? = nil,
        minimumRating: Double? = nil,
        maximumPriceLevel: Int? = nil,
        tags: Set<String>? = nil,
        sources: Set<POISource>? = nil
    ) {
        self.categories = categories
        self.interests = interests
        self.location = location
        self.radiusMiles = radiusMiles
        self.minimumRating = minimumRating
        self.maximumPriceLevel = maximumPriceLevel
        self.tags = tags
        self.sources = sources
    }

    /// Creates a filter for user-personalized POIs.
    public static func forUser(_ user: any UserProfile, near location: GeoLocation, radiusMiles: Double) -> POIFilter {
        POIFilter(
            interests: user.interests,
            location: location,
            radiusMiles: radiusMiles
        )
    }

    /// Creates a filter for EV chargers.
    public static func evChargers(near location: GeoLocation, radiusMiles: Double) -> POIFilter {
        POIFilter(
            categories: [.evCharger],
            location: location,
            radiusMiles: radiusMiles
        )
    }
}

/// Options for sorting POI results.
public enum POISortOrder: Sendable {
    case distance
    case rating
    case name
    case newest
}

/// Service for filtering and discovering points of interest.
public protocol POIFilterService: Sendable {
    /// Filters POIs based on criteria.
    ///
    /// - Parameters:
    ///   - pois: Collection of POIs to filter
    ///   - filter: Filter criteria
    ///   - sortOrder: How to sort results
    /// - Returns: Filtered and sorted POIs
    func filter(
        _ pois: [any PointOfInterest],
        using filter: POIFilter,
        sortedBy sortOrder: POISortOrder
    ) -> [any PointOfInterest]
}

/// Standard implementation of POI filtering.
public struct StandardPOIFilterService: POIFilterService {
    public init() {}

    public func filter(
        _ pois: [any PointOfInterest],
        using filter: POIFilter,
        sortedBy sortOrder: POISortOrder
    ) -> [any PointOfInterest] {
        var filtered = pois

        // Filter by categories
        if let categories = filter.categories {
            filtered = filtered.filter { categories.contains($0.category) }
        }

        // Filter by interests
        if let interests = filter.interests, !interests.isEmpty {
            filtered = filtered.filter { poi in
                let interestCategories = Set(interests.map { $0.category })
                return !poi.category.relatedInterests.isDisjoint(with: interestCategories)
            }
        }

        // Filter by location and radius
        if let location = filter.location, let radius = filter.radiusMiles {
            filtered = filtered.filter { poi in
                poi.location.distance(to: location) <= radius
            }
        }

        // Filter by minimum rating
        if let minimumRating = filter.minimumRating {
            filtered = filtered.filter { poi in
                guard let rating = poi.rating else { return false }
                return rating.averageRating >= minimumRating
            }
        }

        // Filter by maximum price level
        if let maxPrice = filter.maximumPriceLevel {
            filtered = filtered.filter { poi in
                guard let rating = poi.rating, let priceLevel = rating.priceLevel else { return true }
                return priceLevel <= maxPrice
            }
        }

        // Filter by tags
        if let tags = filter.tags, !tags.isEmpty {
            filtered = filtered.filter { poi in
                !poi.tags.isDisjoint(with: tags)
            }
        }

        // Filter by sources
        if let sources = filter.sources {
            filtered = filtered.filter { sources.contains($0.source) }
        }

        // Sort results
        return sort(filtered, by: sortOrder, relativeTo: filter.location)
    }

    private func sort(
        _ pois: [any PointOfInterest],
        by order: POISortOrder,
        relativeTo location: GeoLocation?
    ) -> [any PointOfInterest] {
        switch order {
        case .distance:
            guard let location else { return pois }
            return pois.sorted { poi1, poi2 in
                poi1.location.distance(to: location) < poi2.location.distance(to: location)
            }
        case .rating:
            return pois.sorted { poi1, poi2 in
                let rating1 = poi1.rating?.averageRating ?? 0
                let rating2 = poi2.rating?.averageRating ?? 0
                return rating1 > rating2
            }
        case .name:
            return pois.sorted { $0.name < $1.name }
        case .newest:
            return pois.sorted { $0.createdAt > $1.createdAt }
        }
    }
}

/// Repository protocol for POI data persistence and retrieval.
public protocol POIRepository: Sendable {
    /// Retrieves all POIs.
    func findAll() async throws -> [POI]

    /// Finds POIs matching filter criteria.
    func find(matching filter: POIFilter) async throws -> [POI]

    /// Finds a POI by ID.
    func find(id: UUID) async throws -> POI?

    /// Saves a POI.
    func save(_ poi: POI) async throws -> POI

    /// Deletes a POI.
    func delete(id: UUID) async throws

    /// Finds POIs near a location.
    func findNearby(
        location: GeoLocation,
        radiusMiles: Double,
        categories: Set<POICategory>?
    ) async throws -> [POI]
}

/// In-memory POI repository for testing and demo purposes.
public actor InMemoryPOIRepository: POIRepository {
    private var pois: [UUID: POI] = [:]

    public init(initialPOIs: [POI] = []) {
        for poi in initialPOIs {
            pois[poi.id] = poi
        }
    }

    public func findAll() async throws -> [POI] {
        Array(pois.values)
    }

    public func find(matching filter: POIFilter) async throws -> [POI] {
        let service = StandardPOIFilterService()
        return service.filter(
            Array(pois.values),
            using: filter,
            sortedBy: .distance
        ).compactMap { $0 as? POI }
    }

    public func find(id: UUID) async throws -> POI? {
        pois[id]
    }

    public func save(_ poi: POI) async throws -> POI {
        pois[poi.id] = poi
        return poi
    }

    public func delete(id: UUID) async throws {
        pois.removeValue(forKey: id)
    }

    public func findNearby(
        location: GeoLocation,
        radiusMiles: Double,
        categories: Set<POICategory>?
    ) async throws -> [POI] {
        let filter = POIFilter(
            categories: categories,
            location: location,
            radiusMiles: radiusMiles
        )
        return try await find(matching: filter)
    }
}
