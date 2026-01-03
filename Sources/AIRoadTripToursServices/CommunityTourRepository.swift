import Foundation
import AIRoadTripToursCore

/// Repository for managing community-shared tours.
///
/// Handles tour sharing, ratings, feedback, and automatic promotion of popular tours.
public actor CommunityTourRepository {
    /// Minimum average rating required for automatic sharing.
    private let autoShareThreshold: Double = 4.5

    /// Minimum number of ratings required before auto-sharing.
    private let minRatingsForAutoShare: Int = 3

    /// In-memory storage (replace with actual backend in production).
    private var sharedTours: [UUID: SharedTour] = [:]
    private var ratings: [UUID: [TourRating]] = [:]
    private var feedback: [UUID: [TourFeedback]] = [:]
    private var userRatings: [String: [UUID: TourRating]] = [:]

    public init() {}

    // MARK: - Tour Sharing

    /// Share a tour with the community.
    ///
    /// - Parameters:
    ///   - tourHistory: Completed tour to share
    ///   - userId: User sharing the tour
    ///   - userName: Display name of the user
    ///   - title: Title for the shared tour
    ///   - description: Description of the tour
    ///   - tags: Optional tags for discovery
    /// - Returns: The shared tour
    public func shareTour(
        tourHistory: TourHistory,
        userId: String,
        userName: String,
        title: String,
        description: String,
        tags: Set<String> = [],
        difficulty: TourDifficulty = .moderate,
        bestSeason: Season? = nil
    ) async throws -> SharedTour {
        let categories = Set(tourHistory.pois.map { $0.category })

        let sharedTour = SharedTour(
            creatorId: userId,
            creatorName: userName,
            title: title,
            description: description,
            pois: tourHistory.pois,
            startLocation: tourHistory.startLocation,
            totalDistance: tourHistory.totalDistance,
            estimatedDuration: tourHistory.duration / 3600.0, // Convert seconds to hours
            categories: categories,
            tags: tags,
            difficulty: difficulty,
            bestSeason: bestSeason
        )

        sharedTours[sharedTour.id] = sharedTour
        return sharedTour
    }

    /// Automatically share a tour if it meets quality thresholds.
    ///
    /// - Parameters:
    ///   - tourHistory: Tour to evaluate for auto-sharing
    ///   - userId: User who completed the tour
    ///   - userName: Display name of the user
    /// - Returns: Shared tour if it was auto-shared, nil otherwise
    public func autoShareIfQualified(
        tourHistory: TourHistory,
        userId: String,
        userName: String
    ) async throws -> SharedTour? {
        // Check if user has rated this tour configuration highly
        guard let tourRating = await getUserTourRating(userId: userId, tourHistory: tourHistory),
              tourRating.overallRating >= 5,
              tourRating.completedTour else {
            return nil
        }

        // Auto-share with generated title and description
        let title = generateTourTitle(from: tourHistory)
        let description = generateTourDescription(from: tourHistory, rating: tourRating)
        let tags = generateTags(from: tourHistory)

        let sharedTour = SharedTour(
            creatorId: userId,
            creatorName: userName,
            title: title,
            description: description,
            pois: tourHistory.pois,
            startLocation: tourHistory.startLocation,
            totalDistance: tourHistory.totalDistance,
            estimatedDuration: tourHistory.duration / 3600.0,
            categories: Set(tourHistory.pois.map { $0.category }),
            isAutoShared: true,
            tags: tags,
            difficulty: estimateDifficulty(from: tourHistory)
        )

        sharedTours[sharedTour.id] = sharedTour
        return sharedTour
    }

    // MARK: - Retrieving Tours

    /// Get all shared tours.
    ///
    /// - Parameters:
    ///   - limit: Maximum number of tours to return
    ///   - sortBy: How to sort the results
    /// - Returns: Array of shared tours
    public func getAllTours(
        limit: Int = 50,
        sortBy: TourSortOption = .popularity
    ) async -> [SharedTour] {
        let sorted = Array(sharedTours.values)
            .sorted { tour1, tour2 in
                switch sortBy {
                case .popularity:
                    return tour1.metrics.popularityScore > tour2.metrics.popularityScore
                case .rating:
                    return tour1.metrics.averageRating > tour2.metrics.averageRating
                case .recent:
                    return tour1.sharedAt > tour2.sharedAt
                case .trending:
                    return tour1.metrics.trendingScore > tour2.metrics.trendingScore
                }
            }

        return Array(sorted.prefix(limit))
    }

    /// Get featured/curated tours.
    ///
    /// - Parameter limit: Maximum number of tours to return
    /// - Returns: Array of featured tours
    public func getFeaturedTours(limit: Int = 10) async -> [SharedTour] {
        return Array(sharedTours.values.filter { $0.isFeatured }.prefix(limit))
    }

    /// Get tours near a location.
    ///
    /// - Parameters:
    ///   - location: Reference location
    ///   - radiusMiles: Search radius in miles
    ///   - limit: Maximum number of tours to return
    /// - Returns: Array of nearby tours
    public func getToursNear(
        location: GeoLocation,
        radiusMiles: Double = 50.0,
        limit: Int = 20
    ) async -> [SharedTour] {
        return sharedTours.values
            .filter { tour in
                let distance = location.distance(to: tour.startLocation)
                return distance <= radiusMiles
            }
            .sorted { $0.metrics.popularityScore > $1.metrics.popularityScore }
            .prefix(limit)
            .map { $0 }
    }

    /// Get tours by category.
    ///
    /// - Parameters:
    ///   - categories: Categories to filter by
    ///   - limit: Maximum number of tours to return
    /// - Returns: Array of matching tours
    public func getToursByCategories(
        _ categories: Set<POICategory>,
        limit: Int = 20
    ) async -> [SharedTour] {
        return sharedTours.values
            .filter { tour in
                !tour.categories.isDisjoint(with: categories)
            }
            .sorted { $0.metrics.popularityScore > $1.metrics.popularityScore }
            .prefix(limit)
            .map { $0 }
    }

    /// Search tours by text query.
    ///
    /// - Parameters:
    ///   - query: Search query
    ///   - limit: Maximum number of tours to return
    /// - Returns: Array of matching tours
    public func searchTours(
        query: String,
        limit: Int = 20
    ) async -> [SharedTour] {
        let lowercaseQuery = query.lowercased()

        return sharedTours.values
            .filter { tour in
                tour.title.lowercased().contains(lowercaseQuery) ||
                tour.description.lowercased().contains(lowercaseQuery) ||
                tour.tags.contains { $0.lowercased().contains(lowercaseQuery) }
            }
            .sorted { $0.metrics.popularityScore > $1.metrics.popularityScore }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Ratings

    /// Submit a rating for a tour.
    ///
    /// - Parameters:
    ///   - tourId: ID of the tour to rate
    ///   - userId: User submitting the rating
    ///   - rating: Rating details
    /// - Returns: Updated shared tour with new metrics
    public func submitRating(
        tourId: UUID,
        userId: String,
        rating: TourRating
    ) async throws -> SharedTour {
        guard var tour = sharedTours[tourId] else {
            throw CommunityError.tourNotFound
        }

        // Store rating
        var tourRatings = ratings[tourId] ?? []

        // Remove existing rating from this user if any
        tourRatings.removeAll { $0.userId == userId }
        tourRatings.append(rating)
        ratings[tourId] = tourRatings

        // Update user's rating index
        var userTourRatings = userRatings[userId] ?? [:]
        userTourRatings[tourId] = rating
        userRatings[userId] = userTourRatings

        // Recalculate metrics
        tour.metrics.ratingCount = tourRatings.count
        tour.metrics.averageRating = tourRatings.map { Double($0.overallRating) }
            .reduce(0, +) / Double(tourRatings.count)
        tour.metrics.recalculatePopularityScore()

        // Check if tour qualifies for featuring
        if tour.metrics.averageRating >= autoShareThreshold,
           tour.metrics.ratingCount >= minRatingsForAutoShare,
           !tour.isFeatured {
            tour.isFeatured = true
        }

        sharedTours[tourId] = tour
        return tour
    }

    /// Get ratings for a tour.
    ///
    /// - Parameter tourId: ID of the tour
    /// - Returns: Array of ratings
    public func getRatings(for tourId: UUID) async -> [TourRating] {
        return ratings[tourId] ?? []
    }

    /// Get a user's rating for a tour.
    ///
    /// - Parameters:
    ///   - userId: User ID
    ///   - tourId: Tour ID
    /// - Returns: User's rating if it exists
    public func getUserRating(userId: String, tourId: UUID) async -> TourRating? {
        return userRatings[userId]?[tourId]
    }

    // MARK: - Feedback

    /// Submit feedback for a tour.
    ///
    /// - Parameters:
    ///   - tourId: ID of the tour
    ///   - feedback: Feedback details
    /// - Returns: Updated shared tour
    public func submitFeedback(
        tourId: UUID,
        feedback: TourFeedback
    ) async throws -> SharedTour {
        guard var tour = sharedTours[tourId] else {
            throw CommunityError.tourNotFound
        }

        var tourFeedback = self.feedback[tourId] ?? []
        tourFeedback.append(feedback)
        self.feedback[tourId] = tourFeedback

        tour.metrics.feedbackCount = tourFeedback.count
        tour.metrics.recalculatePopularityScore()

        sharedTours[tourId] = tour
        return tour
    }

    /// Get feedback for a tour.
    ///
    /// - Parameter tourId: ID of the tour
    /// - Returns: Array of feedback
    public func getFeedback(for tourId: UUID) async -> [TourFeedback] {
        return feedback[tourId] ?? []
    }

    /// Mark feedback as helpful.
    ///
    /// - Parameters:
    ///   - feedbackId: ID of the feedback
    ///   - tourId: ID of the tour
    public func markFeedbackHelpful(feedbackId: UUID, tourId: UUID) async {
        guard var tourFeedback = feedback[tourId] else { return }

        if let index = tourFeedback.firstIndex(where: { $0.id == feedbackId }) {
            tourFeedback[index].helpfulCount += 1
            feedback[tourId] = tourFeedback
        }
    }

    // MARK: - Metrics Tracking

    /// Record a tour view.
    ///
    /// - Parameter tourId: ID of the tour viewed
    public func recordView(tourId: UUID) async {
        guard var tour = sharedTours[tourId] else { return }
        tour.metrics.viewCount += 1
        tour.metrics.recalculatePopularityScore()
        sharedTours[tourId] = tour
    }

    /// Record a tour completion.
    ///
    /// - Parameter tourId: ID of the tour completed
    public func recordCompletion(tourId: UUID) async {
        guard var tour = sharedTours[tourId] else { return }
        tour.metrics.completionCount += 1
        tour.metrics.recalculatePopularityScore()
        sharedTours[tourId] = tour
    }

    /// Record a tour save/favorite.
    ///
    /// - Parameter tourId: ID of the tour saved
    public func recordSave(tourId: UUID) async {
        guard var tour = sharedTours[tourId] else { return }
        tour.metrics.saveCount += 1
        tour.metrics.recalculatePopularityScore()
        sharedTours[tourId] = tour
    }

    /// Record a tour share.
    ///
    /// - Parameter tourId: ID of the tour shared
    public func recordShare(tourId: UUID) async {
        guard var tour = sharedTours[tourId] else { return }
        tour.metrics.shareCount += 1
        tour.metrics.recalculatePopularityScore()
        sharedTours[tourId] = tour
    }

    // MARK: - Private Helpers

    private func getUserTourRating(userId: String, tourHistory: TourHistory) async -> TourRating? {
        // Check if user has rated a similar tour
        return userRatings[userId]?.values.first { rating in
            // Match based on POI overlap
            return true // Simplified for now
        }
    }

    private func generateTourTitle(from history: TourHistory) -> String {
        let poiNames = history.pois.prefix(3).map { $0.name }
        if poiNames.count == 1 {
            return poiNames[0]
        } else if poiNames.count == 2 {
            return "\(poiNames[0]) and \(poiNames[1])"
        } else {
            return "\(poiNames[0]), \(poiNames[1]), and \(poiNames.count - 2) more"
        }
    }

    private func generateTourDescription(from history: TourHistory, rating: TourRating) -> String {
        let distance = String(format: "%.1f", history.totalDistance)
        let hours = Int(history.duration / 3600)
        let minutes = Int((history.duration.truncatingRemainder(dividingBy: 3600)) / 60)

        return "A \(distance)-mile journey through \(history.pois.count) amazing locations. Estimated time: \(hours)h \(minutes)m. Highly rated experience!"
    }

    private func generateTags(from history: TourHistory) -> Set<String> {
        var tags = Set<String>()

        // Add category-based tags
        for poi in history.pois {
            tags.insert(poi.category.rawValue)
        }

        // Add distance-based tags
        if history.totalDistance < 50 {
            tags.insert("Short Trip")
        } else if history.totalDistance < 200 {
            tags.insert("Day Trip")
        } else {
            tags.insert("Road Trip")
        }

        // Add POI count tags
        if history.pois.count <= 3 {
            tags.insert("Quick Tour")
        } else if history.pois.count <= 6 {
            tags.insert("Half Day")
        } else {
            tags.insert("Full Day")
        }

        return tags
    }

    private func estimateDifficulty(from history: TourHistory) -> TourDifficulty {
        if history.totalDistance > 300 || history.pois.count > 10 {
            return .challenging
        } else if history.totalDistance > 100 || history.pois.count > 5 {
            return .moderate
        } else {
            return .easy
        }
    }
}

/// Sort options for community tours.
public enum TourSortOption: String, Codable, Sendable, CaseIterable {
    case popularity = "Most Popular"
    case rating = "Highest Rated"
    case recent = "Most Recent"
    case trending = "Trending"
}

/// Errors that can occur with community tours.
public enum CommunityError: Error, LocalizedError {
    case tourNotFound
    case invalidRating
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .tourNotFound:
            return "The requested tour could not be found"
        case .invalidRating:
            return "Rating values must be between 1 and 5"
        case .unauthorized:
            return "You are not authorized to perform this action"
        }
    }
}
