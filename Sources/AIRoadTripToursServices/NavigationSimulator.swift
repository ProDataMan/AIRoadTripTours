import Foundation
import AIRoadTripToursCore

/// Simulates navigation along a route for testing proximity-based features.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public class NavigationSimulator: ObservableObject {

    @Published public var currentLocation: GeoLocation
    @Published public var currentSpeed: Double // mph
    @Published public var isSimulating: Bool = false
    @Published public var routeProgress: Double = 0.0 // 0.0 to 1.0

    private var route: [POI] = []
    private var startLocation: GeoLocation
    private var currentSegmentIndex: Int = 0
    private var simulationTask: Task<Void, Never>?

    public init(startLocation: GeoLocation) {
        self.currentLocation = startLocation
        self.startLocation = startLocation
        self.currentSpeed = 45.0 // Default 45 mph
    }

    /// Starts simulated navigation along a route.
    public func startSimulation(route: [POI], speed: Double = 45.0) {
        self.route = route
        self.currentSpeed = speed
        self.currentSegmentIndex = 0
        self.routeProgress = 0.0
        self.isSimulating = true

        simulationTask?.cancel()
        simulationTask = Task {
            await simulateNavigation()
        }
    }

    /// Stops the simulation.
    public func stopSimulation() {
        simulationTask?.cancel()
        isSimulating = false
        currentSpeed = 0.0
    }

    /// Manually sets location (for scrubber control).
    public func setLocation(_ location: GeoLocation) {
        currentLocation = location
    }

    /// Sets speed multiplier for faster testing.
    public func setSpeed(_ speed: Double) {
        currentSpeed = speed
    }

    /// Jumps to a specific progress point on the route.
    public func jumpToProgress(_ progress: Double) {
        routeProgress = min(max(progress, 0.0), 1.0)

        guard !route.isEmpty else { return }

        // Calculate location at this progress
        let totalSegments = route.count
        let segmentProgress = routeProgress * Double(totalSegments)
        let segmentIndex = min(Int(segmentProgress), totalSegments - 1)
        let withinSegmentProgress = segmentProgress - Double(segmentIndex)

        currentSegmentIndex = segmentIndex

        // Interpolate location within segment
        let startLoc = segmentIndex == 0 ? startLocation : route[segmentIndex - 1].location
        let endLoc = route[segmentIndex].location

        currentLocation = interpolate(
            from: startLoc,
            to: endLoc,
            progress: withinSegmentProgress
        )
    }

    // MARK: - Private

    private func simulateNavigation() async {
        guard !route.isEmpty else { return }

        while currentSegmentIndex < route.count && !Task.isCancelled {
            let segment = route[currentSegmentIndex]
            let startLoc = currentSegmentIndex == 0 ? startLocation : route[currentSegmentIndex - 1].location

            await navigateToward(poi: segment, from: startLoc)

            currentSegmentIndex += 1
        }

        // Reached end of route
        isSimulating = false
        currentSpeed = 0.0
    }

    private func navigateToward(poi: POI, from start: GeoLocation) async {
        let totalDistance = start.distance(to: poi.location)
        let updateIntervalSeconds: Double = 1.0

        // Calculate distance covered per update
        // distance = speed * time
        // speed in mph, time in hours
        let distancePerUpdate = currentSpeed * (updateIntervalSeconds / 3600.0)

        var distanceTraveled: Double = 0.0

        while distanceTraveled < totalDistance && !Task.isCancelled {
            let progress = distanceTraveled / totalDistance

            // Update current location
            currentLocation = interpolate(from: start, to: poi.location, progress: progress)

            // Update overall route progress
            let segmentWeight = 1.0 / Double(route.count)
            routeProgress = (Double(currentSegmentIndex) + progress) * segmentWeight

            // Wait for update interval
            try? await Task.sleep(for: .seconds(updateIntervalSeconds))

            distanceTraveled += distancePerUpdate
        }

        // Snap to final location
        currentLocation = poi.location
    }

    private func interpolate(
        from start: GeoLocation,
        to end: GeoLocation,
        progress: Double
    ) -> GeoLocation {
        let lat = start.latitude + (end.latitude - start.latitude) * progress
        let lon = start.longitude + (end.longitude - start.longitude) * progress

        return GeoLocation(latitude: lat, longitude: lon)
    }
}
