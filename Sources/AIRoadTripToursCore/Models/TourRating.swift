import Foundation

/// User rating for a shared tour.
///
/// Ratings help identify the best tours for automatic sharing and AI curation.
public struct TourRating: Identifiable, Codable, Sendable, Hashable {
    /// Unique identifier for this rating.
    public let id: UUID

    /// ID of the tour being rated.
    public let tourId: UUID

    /// User who provided the rating.
    public let userId: String

    /// Overall rating (1-5 stars).
    public let overallRating: Int

    /// Rating for the route quality (1-5).
    public let routeQuality: Int

    /// Rating for POI selection (1-5).
    public let poiQuality: Int

    /// Rating for narration quality (1-5).
    public let narrationQuality: Int

    /// Rating for the experience (1-5).
    public let experienceRating: Int

    /// When this rating was submitted.
    public let createdAt: Date

    /// Whether the user completed the tour.
    public let completedTour: Bool

    /// When the user took the tour.
    public let tourDate: Date?

    public init(
        id: UUID = UUID(),
        tourId: UUID,
        userId: String,
        overallRating: Int,
        routeQuality: Int,
        poiQuality: Int,
        narrationQuality: Int,
        experienceRating: Int,
        createdAt: Date = Date(),
        completedTour: Bool = false,
        tourDate: Date? = nil
    ) {
        self.id = id
        self.tourId = tourId
        self.userId = userId
        self.overallRating = overallRating
        self.routeQuality = routeQuality
        self.poiQuality = poiQuality
        self.narrationQuality = narrationQuality
        self.experienceRating = experienceRating
        self.createdAt = createdAt
        self.completedTour = completedTour
        self.tourDate = tourDate
    }

    /// Calculate average of all rating components.
    public var averageComponentRating: Double {
        let total = Double(routeQuality + poiQuality + narrationQuality + experienceRating)
        return total / 4.0
    }

    /// Validate that rating values are within acceptable range.
    public var isValid: Bool {
        let ratings = [overallRating, routeQuality, poiQuality, narrationQuality, experienceRating]
        return ratings.allSatisfy { $0 >= 1 && $0 <= 5 }
    }
}

/// Detailed feedback/comment for a shared tour.
///
/// Feedback provides qualitative data for AI-driven tour improvements.
public struct TourFeedback: Identifiable, Codable, Sendable, Hashable {
    /// Unique identifier for this feedback.
    public let id: UUID

    /// ID of the tour receiving feedback.
    public let tourId: UUID

    /// User who provided the feedback.
    public let userId: String

    /// Display name of the user.
    public let userName: String

    /// Feedback comment text.
    public let comment: String

    /// Type of feedback.
    public let type: FeedbackType

    /// Specific aspects being commented on.
    public let aspects: Set<FeedbackAspect>

    /// When this feedback was submitted.
    public let createdAt: Date

    /// Number of users who found this feedback helpful.
    public var helpfulCount: Int

    /// Whether this feedback has been reviewed by moderators.
    public var isReviewed: Bool

    /// Whether this feedback was used in AI-driven updates.
    public var usedInAIUpdate: Bool

    /// Associated rating if applicable.
    public let ratingId: UUID?

    public init(
        id: UUID = UUID(),
        tourId: UUID,
        userId: String,
        userName: String,
        comment: String,
        type: FeedbackType,
        aspects: Set<FeedbackAspect> = [],
        createdAt: Date = Date(),
        helpfulCount: Int = 0,
        isReviewed: Bool = false,
        usedInAIUpdate: Bool = false,
        ratingId: UUID? = nil
    ) {
        self.id = id
        self.tourId = tourId
        self.userId = userId
        self.userName = userName
        self.comment = comment
        self.type = type
        self.aspects = aspects
        self.createdAt = createdAt
        self.helpfulCount = helpfulCount
        self.isReviewed = isReviewed
        self.usedInAIUpdate = usedInAIUpdate
        self.ratingId = ratingId
    }
}

/// Type of feedback provided.
public enum FeedbackType: String, Codable, Sendable, CaseIterable {
    case positive = "Positive"
    case constructive = "Constructive"
    case issue = "Issue"
    case suggestion = "Suggestion"

    public var icon: String {
        switch self {
        case .positive: return "hand.thumbsup"
        case .constructive: return "lightbulb"
        case .issue: return "exclamationmark.triangle"
        case .suggestion: return "star"
        }
    }
}

/// Specific aspects that feedback can address.
public enum FeedbackAspect: String, Codable, Sendable, CaseIterable {
    case route = "Route"
    case pois = "POIs"
    case narration = "Narration"
    case timing = "Timing"
    case directions = "Directions"
    case safety = "Safety"
    case accessibility = "Accessibility"
    case scenicValue = "Scenic Value"
    case historical = "Historical Accuracy"
    case technical = "Technical Issues"
}
