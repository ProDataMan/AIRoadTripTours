import Foundation
#if canImport(MapKit)
import MapKit
#endif
import AIRoadTripToursCore

/// Service for launching navigation to POIs using Apple Maps.
public actor NavigationService {

    public init() {}

    #if canImport(MapKit)
    /// Launches Apple Maps navigation to a specific POI.
    ///
    /// - Parameters:
    ///   - poi: The point of interest to navigate to
    ///   - transportType: Type of transportation (default: .automobile)
    /// - Returns: True if navigation was launched successfully
    @MainActor
    public func navigate(to poi: POI, transportType: MKDirectionsTransportType = .automobile) async -> Bool {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: poi.location.latitude,
            longitude: poi.location.longitude
        ))

        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = poi.name

        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: directionsMode(for: transportType),
            MKLaunchOptionsShowsTrafficKey: true
        ]

        return mapItem.openInMaps(launchOptions: launchOptions)
    }

    /// Launches Apple Maps navigation to a specific location.
    ///
    /// - Parameters:
    ///   - location: The geographic location to navigate to
    ///   - name: Optional name for the destination
    ///   - transportType: Type of transportation (default: .automobile)
    /// - Returns: True if navigation was launched successfully
    @MainActor
    public func navigate(to location: GeoLocation, name: String? = nil, transportType: MKDirectionsTransportType = .automobile) async -> Bool {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        ))

        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name

        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: directionsMode(for: transportType),
            MKLaunchOptionsShowsTrafficKey: true
        ]

        return mapItem.openInMaps(launchOptions: launchOptions)
    }

    /// Fetches route information between two locations.
    ///
    /// - Parameters:
    ///   - from: Starting location
    ///   - to: Destination location
    ///   - transportType: Type of transportation (default: .automobile)
    /// - Returns: Route information including distance, time, and steps
    public func getRoute(from: GeoLocation, to: GeoLocation, transportType: MKDirectionsTransportType = .automobile) async throws -> RouteInfo {
        let sourcePlacemark = MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: from.latitude,
            longitude: from.longitude
        ))
        let destinationPlacemark = MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: to.latitude,
            longitude: to.longitude
        ))

        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)

        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destinationItem
        request.transportType = transportType
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw NavigationError.noRouteFound
        }

        return RouteInfo(
            distance: route.distance * 0.000621371, // meters to miles
            expectedTravelTime: route.expectedTravelTime,
            steps: route.steps.map { step in
                RouteStep(
                    instructions: step.instructions,
                    distance: step.distance * 0.000621371 // meters to miles
                )
            }
        )
    }

    /// Fetches routes for multiple waypoints in sequence.
    ///
    /// - Parameters:
    ///   - from: Starting location
    ///   - waypoints: List of POIs to visit in order
    ///   - transportType: Type of transportation (default: .automobile)
    /// - Returns: Array of route segments between each waypoint
    public func getMultiStopRoute(from: GeoLocation, waypoints: [POI], transportType: MKDirectionsTransportType = .automobile) async throws -> [RouteSegment] {
        var segments: [RouteSegment] = []
        var currentLocation = from

        for poi in waypoints {
            let routeInfo = try await getRoute(
                from: currentLocation,
                to: poi.location,
                transportType: transportType
            )

            segments.append(RouteSegment(
                to: poi,
                routeInfo: routeInfo
            ))

            currentLocation = poi.location
        }

        return segments
    }

    // MARK: - Private Helpers

    private nonisolated func directionsMode(for transportType: MKDirectionsTransportType) -> String {
        switch transportType {
        case .automobile:
            return MKLaunchOptionsDirectionsModeDriving
        case .walking:
            return MKLaunchOptionsDirectionsModeWalking
        case .transit:
            return MKLaunchOptionsDirectionsModeTransit
        default:
            return MKLaunchOptionsDirectionsModeDriving
        }
    }
    #endif
}

/// Information about a calculated route.
public struct RouteInfo: Codable, Sendable {
    /// Total distance in miles
    public let distance: Double

    /// Expected travel time in seconds
    public let expectedTravelTime: TimeInterval

    /// Step-by-step instructions
    public let steps: [RouteStep]

    public init(distance: Double, expectedTravelTime: TimeInterval, steps: [RouteStep]) {
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
        self.steps = steps
    }
}

/// A single step in a route.
public struct RouteStep: Codable, Sendable {
    /// Human-readable instructions for this step
    public let instructions: String

    /// Distance for this step in miles
    public let distance: Double

    public init(instructions: String, distance: Double) {
        self.instructions = instructions
        self.distance = distance
    }
}

/// A segment of a multi-stop route.
public struct RouteSegment: Sendable {
    /// Destination POI for this segment
    public let to: POI

    /// Route information for this segment
    public let routeInfo: RouteInfo

    public init(to: POI, routeInfo: RouteInfo) {
        self.to = to
        self.routeInfo = routeInfo
    }
}

/// Errors that can occur during navigation.
public enum NavigationError: Error, LocalizedError {
    case noRouteFound
    case invalidLocation
    case navigationUnavailable

    public var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "No route could be found to the destination"
        case .invalidLocation:
            return "The location is invalid"
        case .navigationUnavailable:
            return "Navigation is not available on this device"
        }
    }
}
