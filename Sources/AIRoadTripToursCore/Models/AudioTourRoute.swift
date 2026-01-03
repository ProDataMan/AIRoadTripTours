import Foundation

/// Planned audio tour route with waypoints and POIs.
public struct AudioTourRoute: Codable, Sendable, Identifiable {
    public let id: UUID
    public let origin: GeoLocation
    public let destination: GeoLocation
    public let waypoints: [GeoLocation]
    public let segments: [RouteSegment]
    public let totalDistance: Double
    public let estimatedDuration: TimeInterval
    public let pois: [EnrichedPOI]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        origin: GeoLocation,
        destination: GeoLocation,
        waypoints: [GeoLocation],
        segments: [RouteSegment],
        totalDistance: Double,
        estimatedDuration: TimeInterval,
        pois: [EnrichedPOI],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.origin = origin
        self.destination = destination
        self.waypoints = waypoints
        self.segments = segments
        self.totalDistance = totalDistance
        self.estimatedDuration = estimatedDuration
        self.pois = pois
        self.createdAt = createdAt
    }
}

/// A segment of a route between two points.
public struct RouteSegment: Codable, Sendable, Identifiable {
    public let id: UUID
    public let startLocation: GeoLocation
    public let endLocation: GeoLocation
    public let distance: Double
    public let duration: TimeInterval
    public let poi: EnrichedPOI?
    public let nearbyPOIs: [EnrichedPOI]

    public init(
        id: UUID = UUID(),
        startLocation: GeoLocation,
        endLocation: GeoLocation,
        distance: Double,
        duration: TimeInterval,
        poi: EnrichedPOI? = nil,
        nearbyPOIs: [EnrichedPOI] = []
    ) {
        self.id = id
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.distance = distance
        self.duration = duration
        self.poi = poi
        self.nearbyPOIs = nearbyPOIs
    }
}
