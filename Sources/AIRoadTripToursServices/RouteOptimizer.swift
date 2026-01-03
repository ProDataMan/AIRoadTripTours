import Foundation
import AIRoadTripToursCore

/// Simple route optimizer using nearest-neighbor heuristic for TSP.
@available(iOS 17.0, macOS 14.0, *)
public actor RouteOptimizer {

    public init() {}

    /// Optimizes the order of POIs to minimize total travel distance.
    /// Uses a greedy nearest-neighbor algorithm.
    public func optimizeRoute(
        startingFrom origin: GeoLocation,
        visiting pois: [POI]
    ) -> [POI] {
        guard !pois.isEmpty else { return [] }

        var unvisited = Set(pois)
        var route: [POI] = []
        var currentLocation = origin

        // Greedy nearest-neighbor: always visit the closest unvisited POI
        while !unvisited.isEmpty {
            guard let nearest = findNearest(to: currentLocation, in: unvisited) else {
                break
            }

            route.append(nearest)
            unvisited.remove(nearest)
            currentLocation = nearest.location
        }

        return route
    }

    /// Calculates total distance for a route.
    public func calculateTotalDistance(
        from origin: GeoLocation,
        through pois: [POI]
    ) -> Double {
        guard !pois.isEmpty else { return 0 }

        var totalDistance: Double = 0
        var currentLocation = origin

        for poi in pois {
            totalDistance += currentLocation.distance(to: poi.location)
            currentLocation = poi.location
        }

        return totalDistance
    }

    // MARK: - Private Helpers

    private func findNearest(
        to location: GeoLocation,
        in pois: Set<POI>
    ) -> POI? {
        pois.min { poi1, poi2 in
            location.distance(to: poi1.location) < location.distance(to: poi2.location)
        }
    }
}
