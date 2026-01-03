import Foundation
import CoreLocation

/// Represents a geographic location with coordinates.
public struct GeoLocation: Codable, Sendable, Hashable {
    /// Latitude in degrees.
    public let latitude: Double

    /// Longitude in degrees.
    public let longitude: Double

    /// Optional altitude in meters.
    public let altitude: Double?

    /// Optional human-readable address.
    public let address: String?

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        address: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.address = address
    }

    /// Converts to CoreLocation coordinate.
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Calculates distance to another location in miles.
    public func distance(to other: GeoLocation) -> Double {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to) * 0.000621371 // meters to miles
    }
}

/// Types of points of interest.
public enum POICategory: String, Codable, Sendable, CaseIterable {
    case restaurant = "Restaurant"
    case cafe = "Cafe"
    case attraction = "Attraction"
    case park = "Park"
    case museum = "Museum"
    case historicSite = "Historic Site"
    case scenic = "Scenic Viewpoint"
    case hiking = "Hiking Trail"
    case beach = "Beach"
    case lake = "Lake"
    case waterfall = "Waterfall"
    case evCharger = "EV Charger"
    case hotel = "Hotel"
    case shopping = "Shopping"
    case entertainment = "Entertainment"

    /// Maps POI category to user interest categories.
    public var relatedInterests: Set<InterestCategory> {
        switch self {
        case .restaurant, .cafe:
            return [.food]
        case .attraction, .museum, .historicSite:
            return [.culture, .history]
        case .park, .hiking, .waterfall:
            return [.nature, .adventure]
        case .scenic:
            return [.scenic, .nature]
        case .beach, .lake:
            return [.relaxation, .nature]
        case .evCharger:
            return []
        case .hotel:
            return [.relaxation]
        case .shopping:
            return [.shopping]
        case .entertainment:
            return [.entertainment]
        }
    }
}

/// Contact information for a point of interest.
public struct POIContact: Codable, Sendable, Hashable {
    /// Phone number.
    public let phone: String?

    /// Website URL.
    public let website: String?

    /// Email address.
    public let email: String?

    public init(phone: String? = nil, website: String? = nil, email: String? = nil) {
        self.phone = phone
        self.website = website
        self.email = email
    }
}

/// Operating hours for a point of interest.
public struct POIHours: Codable, Sendable, Hashable {
    /// Textual description of hours (e.g., "Mon-Fri 9am-5pm").
    public let description: String

    /// Whether currently open.
    public let isOpenNow: Bool?

    public init(description: String, isOpenNow: Bool? = nil) {
        self.description = description
        self.isOpenNow = isOpenNow
    }
}

/// User rating and review information.
public struct POIRating: Codable, Sendable, Hashable {
    /// Average rating (0.0 to 5.0).
    public let averageRating: Double

    /// Total number of ratings.
    public let totalRatings: Int

    /// Price level (1-4, where 1 is least expensive).
    public let priceLevel: Int?

    public init(averageRating: Double, totalRatings: Int, priceLevel: Int? = nil) {
        self.averageRating = averageRating
        self.totalRatings = totalRatings
        self.priceLevel = priceLevel
    }
}

/// Source attribution for POI data.
public enum POISource: String, Codable, Sendable {
    case google = "Google Places"
    case yelp = "Yelp"
    case foursquare = "Foursquare"
    case userSubmitted = "User Submitted"
    case curated = "Curated"
}

/// Defines the contract for a point of interest.
public protocol PointOfInterest: Identifiable, Codable, Sendable {
    /// Unique identifier.
    var id: UUID { get }

    /// POI name.
    var name: String { get }

    /// Brief description.
    var description: String? { get }

    /// Category.
    var category: POICategory { get }

    /// Geographic location.
    var location: GeoLocation { get }

    /// Contact information.
    var contact: POIContact? { get }

    /// Operating hours.
    var hours: POIHours? { get }

    /// Rating and review information.
    var rating: POIRating? { get }

    /// Data source.
    var source: POISource { get }

    /// Tags for additional categorization.
    var tags: Set<String> { get }

    /// Creation timestamp.
    var createdAt: Date { get }

    /// Last update timestamp.
    var updatedAt: Date { get }
}

/// Concrete implementation of a point of interest.
public struct POI: PointOfInterest, Hashable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let category: POICategory
    public let location: GeoLocation
    public let contact: POIContact?
    public let hours: POIHours?
    public let rating: POIRating?
    public let source: POISource
    public let tags: Set<String>
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        category: POICategory,
        location: GeoLocation,
        contact: POIContact? = nil,
        hours: POIHours? = nil,
        rating: POIRating? = nil,
        source: POISource = .curated,
        tags: Set<String> = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.location = location
        self.contact = contact
        self.hours = hours
        self.rating = rating
        self.source = source
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Checks if this POI matches user interests.
    public func matches(interests: Set<UserInterest>) -> Bool {
        let interestCategories = Set(interests.map { $0.category })
        return !category.relatedInterests.isDisjoint(with: interestCategories)
    }

    /// Checks if POI is within a distance radius.
    public func isWithin(miles: Double, of location: GeoLocation) -> Bool {
        self.location.distance(to: location) <= miles
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: POI, rhs: POI) -> Bool {
        lhs.id == rhs.id
    }
}
