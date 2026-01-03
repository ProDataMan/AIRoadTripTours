import Foundation

/// Represents a stop on a tour route.
public struct Waypoint: Identifiable, Codable, Sendable, Hashable {
    /// Unique identifier.
    public let id: UUID

    /// Associated POI, if any.
    public let poiId: UUID?

    /// Location of this waypoint.
    public let location: GeoLocation

    /// Display name for this waypoint.
    public let name: String

    /// Optional description or notes.
    public let notes: String?

    /// Estimated duration at this stop in minutes.
    public let durationMinutes: Int

    /// Order in the tour sequence.
    public let sequenceNumber: Int

    /// Whether this is a charging stop.
    public let isChargingStop: Bool

    /// Expected battery level on arrival (0.0 to 1.0).
    public var expectedBatteryOnArrival: Double?

    /// Expected battery level on departure (0.0 to 1.0).
    public var expectedBatteryOnDeparture: Double?

    public init(
        id: UUID = UUID(),
        poiId: UUID? = nil,
        location: GeoLocation,
        name: String,
        notes: String? = nil,
        durationMinutes: Int = 30,
        sequenceNumber: Int,
        isChargingStop: Bool = false,
        expectedBatteryOnArrival: Double? = nil,
        expectedBatteryOnDeparture: Double? = nil
    ) {
        self.id = id
        self.poiId = poiId
        self.location = location
        self.name = name
        self.notes = notes
        self.durationMinutes = durationMinutes
        self.sequenceNumber = sequenceNumber
        self.isChargingStop = isChargingStop
        self.expectedBatteryOnArrival = expectedBatteryOnArrival
        self.expectedBatteryOnDeparture = expectedBatteryOnDeparture
    }
}

/// Status of a tour.
public enum TourStatus: String, Codable, Sendable {
    case draft = "Draft"
    case planned = "Planned"
    case active = "Active"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

/// Represents a planned tour or road trip.
public struct Tour: Identifiable, Codable, Sendable {
    /// Unique identifier.
    public let id: UUID

    /// Tour name.
    public var name: String

    /// Tour description.
    public var description: String?

    /// Waypoints in order.
    public var waypoints: [Waypoint]

    /// User who created this tour.
    public let creatorId: UUID

    /// Vehicle to be used for this tour.
    public let vehicleId: UUID

    /// Current status.
    public var status: TourStatus

    /// Total distance in miles.
    public var totalDistanceMiles: Double

    /// Estimated total duration in minutes.
    public var estimatedDurationMinutes: Int

    /// Creation timestamp.
    public let createdAt: Date

    /// Last update timestamp.
    public var updatedAt: Date

    /// Whether tour is safe for the vehicle's range.
    public var isSafeForVehicle: Bool

    /// Driving conditions for this tour.
    public var conditions: DrivingConditions

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        waypoints: [Waypoint] = [],
        creatorId: UUID,
        vehicleId: UUID,
        status: TourStatus = .draft,
        totalDistanceMiles: Double = 0,
        estimatedDurationMinutes: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSafeForVehicle: Bool = false,
        conditions: DrivingConditions = .standard
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.waypoints = waypoints
        self.creatorId = creatorId
        self.vehicleId = vehicleId
        self.status = status
        self.totalDistanceMiles = totalDistanceMiles
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSafeForVehicle = isSafeForVehicle
        self.conditions = conditions
    }

    /// Returns waypoints sorted by sequence number.
    public var orderedWaypoints: [Waypoint] {
        waypoints.sorted { $0.sequenceNumber < $1.sequenceNumber }
    }

    /// Returns only charging stop waypoints.
    public var chargingStops: [Waypoint] {
        waypoints.filter { $0.isChargingStop }
    }

    /// Returns only POI waypoints (non-charging).
    public var poiStops: [Waypoint] {
        waypoints.filter { !$0.isChargingStop }
    }
}

/// Result of tour planning operation.
public struct TourPlanningResult: Sendable {
    /// The planned tour.
    public let tour: Tour

    /// Whether the tour is safe without modifications.
    public let isSafeWithoutChargers: Bool

    /// Whether chargers were added.
    public let chargersAdded: Bool

    /// Number of charging stops added.
    public let chargingStopsCount: Int

    /// Warnings or recommendations.
    public let warnings: [String]

    public init(
        tour: Tour,
        isSafeWithoutChargers: Bool,
        chargersAdded: Bool,
        chargingStopsCount: Int,
        warnings: [String] = []
    ) {
        self.tour = tour
        self.isSafeWithoutChargers = isSafeWithoutChargers
        self.chargersAdded = chargersAdded
        self.chargingStopsCount = chargingStopsCount
        self.warnings = warnings
    }
}

/// Service for planning tours with EV range validation.
public protocol TourPlanner: Sendable {
    /// Creates a tour from POIs with automatic charger placement.
    ///
    /// - Parameters:
    ///   - name: Tour name
    ///   - pois: Points of interest to visit
    ///   - vehicle: Vehicle for the tour
    ///   - startingBatteryPercent: Battery level at start (0.0 to 1.0)
    ///   - conditions: Driving conditions
    ///   - poiRepository: Repository to find charging stations
    /// - Returns: Tour planning result with chargers added if needed
    func createTour(
        name: String,
        pois: [POI],
        vehicle: any Vehicle,
        startingBatteryPercent: Double,
        conditions: DrivingConditions,
        poiRepository: any POIRepository
    ) async throws -> TourPlanningResult

    /// Validates if a tour is safe for the given vehicle.
    ///
    /// - Parameters:
    ///   - tour: Tour to validate
    ///   - vehicle: Vehicle for the tour
    ///   - startingBatteryPercent: Battery level at start
    ///   - conditions: Driving conditions
    /// - Returns: True if tour can be completed safely
    func validateTourSafety(
        tour: Tour,
        vehicle: any Vehicle,
        startingBatteryPercent: Double,
        conditions: DrivingConditions
    ) -> Bool

    /// Adds charging stops to a tour as needed.
    ///
    /// - Parameters:
    ///   - tour: Tour to modify
    ///   - vehicle: Vehicle for the tour
    ///   - startingBatteryPercent: Battery level at start
    ///   - conditions: Driving conditions
    ///   - poiRepository: Repository to find charging stations
    /// - Returns: Modified tour with charging stops added
    func addChargingStops(
        to tour: Tour,
        vehicle: any Vehicle,
        startingBatteryPercent: Double,
        conditions: DrivingConditions,
        poiRepository: any POIRepository
    ) async throws -> Tour
}

/// Standard implementation of tour planning service.
public struct StandardTourPlanner: TourPlanner {
    private let rangeEstimator: RangeEstimator
    private let maxChargerSearchRadiusMiles: Double
    private let targetBatteryAfterCharge: Double

    public init(
        rangeEstimator: RangeEstimator = SimpleRangeEstimator(),
        maxChargerSearchRadiusMiles: Double = 50.0,
        targetBatteryAfterCharge: Double = 0.80
    ) {
        self.rangeEstimator = rangeEstimator
        self.maxChargerSearchRadiusMiles = maxChargerSearchRadiusMiles
        self.targetBatteryAfterCharge = targetBatteryAfterCharge
    }

    public func createTour(
        name: String,
        pois: [POI],
        vehicle: any Vehicle,
        startingBatteryPercent: Double,
        conditions: DrivingConditions,
        poiRepository: any POIRepository
    ) async throws -> TourPlanningResult {
        // Create initial waypoints from POIs
        var waypoints: [Waypoint] = pois.enumerated().map { index, poi in
            Waypoint(
                poiId: poi.id,
                location: poi.location,
                name: poi.name,
                notes: poi.description,
                durationMinutes: 60,
                sequenceNumber: index
            )
        }

        // Calculate distances and total
        var totalDistance: Double = 0
        for i in 0..<waypoints.count - 1 {
            let distance = waypoints[i].location.distance(to: waypoints[i + 1].location)
            totalDistance += distance
        }

        // Create initial tour
        var tour = Tour(
            name: name,
            waypoints: waypoints,
            creatorId: UUID(), // Would come from user context
            vehicleId: vehicle.id,
            totalDistanceMiles: totalDistance,
            estimatedDurationMinutes: waypoints.reduce(0) { $0 + $1.durationMinutes },
            conditions: conditions
        )

        // Check if safe without chargers
        let isSafe = validateTourSafety(
            tour: tour,
            vehicle: vehicle,
            startingBatteryPercent: startingBatteryPercent,
            conditions: conditions
        )

        if isSafe {
            tour.isSafeForVehicle = true
            return TourPlanningResult(
                tour: tour,
                isSafeWithoutChargers: true,
                chargersAdded: false,
                chargingStopsCount: 0
            )
        }

        // Add charging stops
        tour = try await addChargingStops(
            to: tour,
            vehicle: vehicle,
            startingBatteryPercent: startingBatteryPercent,
            conditions: conditions,
            poiRepository: poiRepository
        )

        return TourPlanningResult(
            tour: tour,
            isSafeWithoutChargers: false,
            chargersAdded: true,
            chargingStopsCount: tour.chargingStops.count,
            warnings: tour.chargingStops.isEmpty ? ["Could not find charging stations along route"] : []
        )
    }

    public func validateTourSafety(
        tour: Tour,
        vehicle: any Vehicle,
        startingBatteryPercent: Double,
        conditions: DrivingConditions
    ) -> Bool {
        var currentBattery = startingBatteryPercent
        let waypoints = tour.orderedWaypoints

        for i in 0..<waypoints.count {
            let waypoint = waypoints[i]

            // Calculate distance to this waypoint
            let distance: Double
            if i == 0 {
                distance = 0 // First waypoint
            } else {
                distance = waypoints[i - 1].location.distance(to: waypoint.location)
            }

            // Check if we can reach this waypoint
            if !rangeEstimator.isTripSafe(
                vehicle: vehicle,
                currentBatteryPercent: currentBattery,
                distanceMiles: distance,
                conditions: conditions
            ) {
                return false
            }

            // Deduct battery for this leg
            let required = rangeEstimator.requiredBatteryForTrip(
                vehicle: vehicle,
                distanceMiles: distance,
                conditions: conditions
            )
            currentBattery -= required

            // Add battery if this is a charging stop
            if waypoint.isChargingStop {
                currentBattery = min(targetBatteryAfterCharge, 1.0)
            }
        }

        return true
    }

    public func addChargingStops(
        to tour: Tour,
        vehicle: any Vehicle,
        startingBatteryPercent: Double,
        conditions: DrivingConditions,
        poiRepository: any POIRepository
    ) async throws -> Tour {
        var modifiedTour = tour
        var waypoints = tour.orderedWaypoints
        var currentBattery = startingBatteryPercent
        var insertedChargers = 0

        for i in 0..<waypoints.count {
            let adjustedIndex = i + insertedChargers
            let waypoint = waypoints[i]

            // Calculate distance to this waypoint
            let distance: Double
            let previousLocation: GeoLocation
            if adjustedIndex == 0 {
                continue // Skip first waypoint
            } else {
                let prevWaypoint = modifiedTour.waypoints[adjustedIndex - 1]
                previousLocation = prevWaypoint.location
                distance = previousLocation.distance(to: waypoint.location)
            }

            // Check if we need charging before reaching this waypoint
            let canReach = rangeEstimator.isTripSafe(
                vehicle: vehicle,
                currentBatteryPercent: currentBattery,
                distanceMiles: distance,
                conditions: conditions
            )

            if !canReach {
                // Find chargers between previous waypoint and current
                let midpoint = GeoLocation(
                    latitude: (previousLocation.latitude + waypoint.location.latitude) / 2,
                    longitude: (previousLocation.longitude + waypoint.location.longitude) / 2
                )

                let chargers = try await poiRepository.findNearby(
                    location: midpoint,
                    radiusMiles: maxChargerSearchRadiusMiles,
                    categories: [.evCharger]
                )

                if let nearestCharger = chargers.first {
                    // Insert charging stop
                    let chargingWaypoint = Waypoint(
                        poiId: nearestCharger.id,
                        location: nearestCharger.location,
                        name: nearestCharger.name,
                        notes: "Charging stop",
                        durationMinutes: 30,
                        sequenceNumber: adjustedIndex,
                        isChargingStop: true
                    )

                    modifiedTour.waypoints.insert(chargingWaypoint, at: adjustedIndex)
                    insertedChargers += 1

                    // Recalculate battery after charging
                    currentBattery = targetBatteryAfterCharge
                }
            }

            // Update battery for this leg
            let required = rangeEstimator.requiredBatteryForTrip(
                vehicle: vehicle,
                distanceMiles: distance,
                conditions: conditions
            )
            currentBattery -= required

            if waypoint.isChargingStop {
                currentBattery = targetBatteryAfterCharge
            }
        }

        // Renumber waypoints
        modifiedTour.waypoints = modifiedTour.waypoints.enumerated().map { index, waypoint in
            var updated = waypoint
            updated = Waypoint(
                id: waypoint.id,
                poiId: waypoint.poiId,
                location: waypoint.location,
                name: waypoint.name,
                notes: waypoint.notes,
                durationMinutes: waypoint.durationMinutes,
                sequenceNumber: index,
                isChargingStop: waypoint.isChargingStop,
                expectedBatteryOnArrival: waypoint.expectedBatteryOnArrival,
                expectedBatteryOnDeparture: waypoint.expectedBatteryOnDeparture
            )
            return updated
        }

        modifiedTour.isSafeForVehicle = validateTourSafety(
            tour: modifiedTour,
            vehicle: vehicle,
            startingBatteryPercent: startingBatteryPercent,
            conditions: conditions
        )

        return modifiedTour
    }
}
