import Foundation

/// Complete tour record with full POI details.
///
/// Used for detailed tour analysis, sharing, and rating.
public struct TourHistory: Codable, Sendable, Identifiable {
    public let id: UUID
    public let pois: [POI]
    public let startLocation: GeoLocation
    public let startTime: Date
    public let endTime: Date
    public let totalDistance: Double
    public let duration: TimeInterval
    public let stats: TourStatistics

    public init(
        id: UUID = UUID(),
        pois: [POI],
        startLocation: GeoLocation,
        startTime: Date,
        endTime: Date,
        totalDistance: Double,
        stats: TourStatistics
    ) {
        self.id = id
        self.pois = pois
        self.startLocation = startLocation
        self.startTime = startTime
        self.endTime = endTime
        self.totalDistance = totalDistance
        self.duration = endTime.timeIntervalSince(startTime)
        self.stats = stats
    }
}

/// Tour history entry recording a completed tour.
public struct TourHistoryEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public let tourId: UUID
    public let tourName: String
    public let completedAt: Date
    public let durationMinutes: Int
    public let distanceMiles: Double
    public let poisVisited: Int
    public let routeCoordinates: [GeoLocation]

    public init(
        id: UUID = UUID(),
        tourId: UUID,
        tourName: String,
        completedAt: Date = Date(),
        durationMinutes: Int,
        distanceMiles: Double,
        poisVisited: Int,
        routeCoordinates: [GeoLocation]
    ) {
        self.id = id
        self.tourId = tourId
        self.tourName = tourName
        self.completedAt = completedAt
        self.durationMinutes = durationMinutes
        self.distanceMiles = distanceMiles
        self.poisVisited = poisVisited
        self.routeCoordinates = routeCoordinates
    }
}

/// User statistics aggregated from tour history.
public struct TourStatistics: Codable, Sendable {
    public let totalToursCompleted: Int
    public let totalDistanceMiles: Double
    public let totalPOIsVisited: Int
    public let totalTimeMinutes: Int
    public let firstTourDate: Date?
    public let lastTourDate: Date?
    public let favoritePOICategories: [String]
    public let longestTourMiles: Double
    public let mostPOIsInOneTour: Int

    public init(
        totalToursCompleted: Int,
        totalDistanceMiles: Double,
        totalPOIsVisited: Int,
        totalTimeMinutes: Int,
        firstTourDate: Date?,
        lastTourDate: Date?,
        favoritePOICategories: [String],
        longestTourMiles: Double,
        mostPOIsInOneTour: Int
    ) {
        self.totalToursCompleted = totalToursCompleted
        self.totalDistanceMiles = totalDistanceMiles
        self.totalPOIsVisited = totalPOIsVisited
        self.totalTimeMinutes = totalTimeMinutes
        self.firstTourDate = firstTourDate
        self.lastTourDate = lastTourDate
        self.favoritePOICategories = favoritePOICategories
        self.longestTourMiles = longestTourMiles
        self.mostPOIsInOneTour = mostPOIsInOneTour
    }

    public static var empty: TourStatistics {
        TourStatistics(
            totalToursCompleted: 0,
            totalDistanceMiles: 0.0,
            totalPOIsVisited: 0,
            totalTimeMinutes: 0,
            firstTourDate: nil,
            lastTourDate: nil,
            favoritePOICategories: [],
            longestTourMiles: 0.0,
            mostPOIsInOneTour: 0
        )
    }
}
