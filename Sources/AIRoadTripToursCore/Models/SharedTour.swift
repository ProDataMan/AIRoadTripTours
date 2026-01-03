import Foundation

/// A tour that has been shared with the community.
///
/// Shared tours include the route, POIs, ratings, and community feedback.
/// Tours with high ratings can be automatically promoted to the community.
public struct SharedTour: Identifiable, Codable, Sendable, Hashable {
    /// Unique identifier for the shared tour.
    public let id: UUID

    /// User who shared the tour.
    public let creatorId: String

    /// Display name of the creator.
    public let creatorName: String

    /// Title of the tour.
    public let title: String

    /// Description of what makes this tour special.
    public let description: String

    /// POIs included in this tour, in order.
    public let pois: [POI]

    /// Starting location for the tour.
    public let startLocation: GeoLocation

    /// Total distance of the tour in miles.
    public let totalDistance: Double

    /// Estimated duration in hours.
    public let estimatedDuration: Double

    /// Categories that describe this tour.
    public let categories: Set<POICategory>

    /// When the tour was shared.
    public let sharedAt: Date

    /// Whether this tour was automatically shared based on high ratings.
    public let isAutoShared: Bool

    /// Whether this tour has been curated and verified by the community.
    public let isCurated: Bool

    /// Community metrics for this tour.
    public var metrics: CommunityMetrics

    /// Tags for discovery and filtering.
    public let tags: Set<String>

    /// Difficulty level of the tour.
    public let difficulty: TourDifficulty

    /// Best time of year to take this tour.
    public let bestSeason: Season?

    /// Whether this tour is featured/promoted.
    public var isFeatured: Bool

    /// Version number for AI-driven updates.
    public let version: Int

    /// Last time this tour was updated.
    public let lastUpdated: Date

    public init(
        id: UUID = UUID(),
        creatorId: String,
        creatorName: String,
        title: String,
        description: String,
        pois: [POI],
        startLocation: GeoLocation,
        totalDistance: Double,
        estimatedDuration: Double,
        categories: Set<POICategory>,
        sharedAt: Date = Date(),
        isAutoShared: Bool = false,
        isCurated: Bool = false,
        metrics: CommunityMetrics = CommunityMetrics(),
        tags: Set<String> = [],
        difficulty: TourDifficulty = .moderate,
        bestSeason: Season? = nil,
        isFeatured: Bool = false,
        version: Int = 1,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.title = title
        self.description = description
        self.pois = pois
        self.startLocation = startLocation
        self.totalDistance = totalDistance
        self.estimatedDuration = estimatedDuration
        self.categories = categories
        self.sharedAt = sharedAt
        self.isAutoShared = isAutoShared
        self.isCurated = isCurated
        self.metrics = metrics
        self.tags = tags
        self.difficulty = difficulty
        self.bestSeason = bestSeason
        self.isFeatured = isFeatured
        self.version = version
        self.lastUpdated = lastUpdated
    }
}

/// Difficulty level for a tour.
public enum TourDifficulty: String, Codable, Sendable, CaseIterable {
    case easy = "Easy"
    case moderate = "Moderate"
    case challenging = "Challenging"

    public var description: String {
        switch self {
        case .easy:
            return "Suitable for all travelers, short distances, easy access"
        case .moderate:
            return "Moderate driving, some longer segments, varied terrain"
        case .challenging:
            return "Long distances, remote areas, adventurous routes"
        }
    }
}

/// Season for optimal tour experience.
public enum Season: String, Codable, Sendable, CaseIterable {
    case spring = "Spring"
    case summer = "Summer"
    case fall = "Fall"
    case winter = "Winter"
    case yearRound = "Year Round"
}

/// Community engagement metrics for a shared tour.
public struct CommunityMetrics: Codable, Sendable, Hashable {
    /// Number of times this tour has been viewed.
    public var viewCount: Int

    /// Number of times this tour has been completed.
    public var completionCount: Int

    /// Number of times this tour has been saved/favorited.
    public var saveCount: Int

    /// Number of times this tour has been shared.
    public var shareCount: Int

    /// Average rating from all users.
    public var averageRating: Double

    /// Total number of ratings.
    public var ratingCount: Int

    /// Number of feedback comments.
    public var feedbackCount: Int

    /// Popularity score calculated from all metrics.
    public var popularityScore: Double

    /// Trending score based on recent activity.
    public var trendingScore: Double

    public init(
        viewCount: Int = 0,
        completionCount: Int = 0,
        saveCount: Int = 0,
        shareCount: Int = 0,
        averageRating: Double = 0.0,
        ratingCount: Int = 0,
        feedbackCount: Int = 0,
        popularityScore: Double = 0.0,
        trendingScore: Double = 0.0
    ) {
        self.viewCount = viewCount
        self.completionCount = completionCount
        self.saveCount = saveCount
        self.shareCount = shareCount
        self.averageRating = averageRating
        self.ratingCount = ratingCount
        self.feedbackCount = feedbackCount
        self.popularityScore = popularityScore
        self.trendingScore = trendingScore
    }

    /// Calculate popularity score based on all metrics.
    public mutating func recalculatePopularityScore() {
        // Weight different metrics
        let viewWeight = 1.0
        let completionWeight = 5.0
        let saveWeight = 3.0
        let shareWeight = 4.0
        let ratingWeight = 2.0

        let score = (Double(viewCount) * viewWeight) +
                    (Double(completionCount) * completionWeight) +
                    (Double(saveCount) * saveWeight) +
                    (Double(shareCount) * shareWeight) +
                    (averageRating * Double(ratingCount) * ratingWeight)

        self.popularityScore = score
    }
}
