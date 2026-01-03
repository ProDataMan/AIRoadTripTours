import Testing
import Foundation
@testable import AIRoadTripToursCore

@Suite("Waypoint Management", .tags(.small))
struct WaypointTests {

    @Test("Creates waypoint with required fields")
    func testWaypointCreation() async throws {
        // Arrange & Act
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let waypoint = Waypoint(
            location: location,
            name: "Portland Stop",
            sequenceNumber: 0
        )

        // Assert
        #expect(waypoint.name == "Portland Stop")
        #expect(waypoint.location.latitude == 45.5152)
        #expect(waypoint.sequenceNumber == 0)
        #expect(!waypoint.isChargingStop)
    }

    @Test("Creates charging stop waypoint")
    func testChargingWaypoint() async throws {
        // Arrange & Act
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let waypoint = Waypoint(
            location: location,
            name: "Supercharger",
            durationMinutes: 30,
            sequenceNumber: 1,
            isChargingStop: true
        )

        // Assert
        #expect(waypoint.isChargingStop)
        #expect(waypoint.durationMinutes == 30)
    }

    @Test("Associates waypoint with POI")
    func testWaypointWithPOI() async throws {
        // Arrange
        let poiId = UUID()
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)

        // Act
        let waypoint = Waypoint(
            poiId: poiId,
            location: location,
            name: "Multnomah Falls",
            sequenceNumber: 0
        )

        // Assert
        #expect(waypoint.poiId == poiId)
    }
}

@Suite("Tour Creation and Management", .tags(.small))
struct TourTests {

    @Test("Creates tour with basic information")
    func testTourCreation() async throws {
        // Arrange
        let userId = UUID()
        let vehicleId = UUID()

        // Act
        let tour = Tour(
            name: "Oregon Coast Road Trip",
            description: "Beautiful coastal drive",
            creatorId: userId,
            vehicleId: vehicleId
        )

        // Assert
        #expect(tour.name == "Oregon Coast Road Trip")
        #expect(tour.status == .draft)
        #expect(tour.waypoints.isEmpty)
        #expect(!tour.isSafeForVehicle)
    }

    @Test("Tour orders waypoints by sequence number")
    func testOrderedWaypoints() async throws {
        // Arrange
        let location1 = GeoLocation(latitude: 45.5, longitude: -122.6)
        let location2 = GeoLocation(latitude: 45.6, longitude: -122.7)
        let location3 = GeoLocation(latitude: 45.7, longitude: -122.8)

        let waypoint1 = Waypoint(location: location1, name: "Stop 1", sequenceNumber: 0)
        let waypoint2 = Waypoint(location: location2, name: "Stop 2", sequenceNumber: 1)
        let waypoint3 = Waypoint(location: location3, name: "Stop 3", sequenceNumber: 2)

        // Act - add in wrong order
        let tour = Tour(
            name: "Test Tour",
            waypoints: [waypoint3, waypoint1, waypoint2],
            creatorId: UUID(),
            vehicleId: UUID()
        )

        // Assert - should be ordered correctly
        let ordered = tour.orderedWaypoints
        #expect(ordered[0].name == "Stop 1")
        #expect(ordered[1].name == "Stop 2")
        #expect(ordered[2].name == "Stop 3")
    }

    @Test("Tour filters charging stops")
    func testChargingStopsFilter() async throws {
        // Arrange
        let location = GeoLocation(latitude: 45.5, longitude: -122.6)
        let poi = Waypoint(location: location, name: "Museum", sequenceNumber: 0)
        let charger1 = Waypoint(
            location: location,
            name: "Charger 1",
            sequenceNumber: 1,
            isChargingStop: true
        )
        let charger2 = Waypoint(
            location: location,
            name: "Charger 2",
            sequenceNumber: 2,
            isChargingStop: true
        )

        // Act
        let tour = Tour(
            name: "Test Tour",
            waypoints: [poi, charger1, charger2],
            creatorId: UUID(),
            vehicleId: UUID()
        )

        // Assert
        #expect(tour.chargingStops.count == 2)
        #expect(tour.poiStops.count == 1)
    }
}

@Suite("Tour Safety Validation", .tags(.medium))
struct TourSafetyTests {
    let planner = StandardTourPlanner()
    let tesla = EVProfile(
        make: "Tesla",
        model: "Model 3",
        year: 2024,
        batteryCapacityKWh: 75.0,
        chargingPorts: [.nacs],
        estimatedRangeMiles: 272.0,
        consumptionRateKWhPerMile: 0.276
    )

    @Test("Validates safe short tour")
    func testSafeShortTour() async throws {
        // Arrange - 3 stops within 100 miles total
        let location1 = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let location2 = GeoLocation(latitude: 45.5762, longitude: -122.1153) // ~30 miles
        let location3 = GeoLocation(latitude: 45.6878, longitude: -121.9405) // ~20 more miles

        let waypoints = [
            Waypoint(location: location1, name: "Start", sequenceNumber: 0),
            Waypoint(location: location2, name: "Stop 1", sequenceNumber: 1),
            Waypoint(location: location3, name: "Stop 2", sequenceNumber: 2)
        ]

        let tour = Tour(
            name: "Short Tour",
            waypoints: waypoints,
            creatorId: UUID(),
            vehicleId: tesla.id
        )

        // Act
        let isSafe = planner.validateTourSafety(
            tour: tour,
            vehicle: tesla,
            startingBatteryPercent: 0.80,
            conditions: .standard
        )

        // Assert
        #expect(isSafe)
    }

    @Test("Detects unsafe long tour without charging")
    func testUnsafeLongTour() async throws {
        // Arrange - tour longer than vehicle range
        let location1 = GeoLocation(latitude: 45.5152, longitude: -122.6784) // Portland
        let location2 = GeoLocation(latitude: 42.8684, longitude: -122.1685) // Crater Lake (~230 miles)

        let waypoints = [
            Waypoint(location: location1, name: "Portland", sequenceNumber: 0),
            Waypoint(location: location2, name: "Crater Lake", sequenceNumber: 1)
        ]

        let tour = Tour(
            name: "Long Tour",
            waypoints: waypoints,
            creatorId: UUID(),
            vehicleId: tesla.id
        )

        // Act - with only 50% battery
        let isSafe = planner.validateTourSafety(
            tour: tour,
            vehicle: tesla,
            startingBatteryPercent: 0.50,
            conditions: .standard
        )

        // Assert
        #expect(!isSafe)
    }

    @Test("Validates tour with charging stop")
    func testTourWithChargingStop() async throws {
        // Arrange
        let location1 = GeoLocation(latitude: 45.5152, longitude: -122.6784) // Portland
        let chargerLocation = GeoLocation(latitude: 44.0, longitude: -122.0) // Midpoint
        let location2 = GeoLocation(latitude: 42.8684, longitude: -122.1685) // Crater Lake

        let waypoints = [
            Waypoint(location: location1, name: "Portland", sequenceNumber: 0),
            Waypoint(
                location: chargerLocation,
                name: "Charger",
                durationMinutes: 30,
                sequenceNumber: 1,
                isChargingStop: true
            ),
            Waypoint(location: location2, name: "Crater Lake", sequenceNumber: 2)
        ]

        let tour = Tour(
            name: "Tour with Charger",
            waypoints: waypoints,
            creatorId: UUID(),
            vehicleId: tesla.id
        )

        // Act
        let isSafe = planner.validateTourSafety(
            tour: tour,
            vehicle: tesla,
            startingBatteryPercent: 0.80,
            conditions: .standard
        )

        // Assert
        #expect(isSafe)
    }

    @Test("Accounts for cold weather in tour safety")
    func testColdWeatherTourSafety() async throws {
        // Arrange
        let location1 = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let location2 = GeoLocation(latitude: 45.8, longitude: -122.0) // ~50 miles

        let waypoints = [
            Waypoint(location: location1, name: "Start", sequenceNumber: 0),
            Waypoint(location: location2, name: "End", sequenceNumber: 1)
        ]

        let tour = Tour(
            name: "Winter Tour",
            waypoints: waypoints,
            creatorId: UUID(),
            vehicleId: tesla.id,
            conditions: DrivingConditions(temperatureFahrenheit: 20.0)
        )

        // Act - same battery level, different conditions
        let safeInStandard = planner.validateTourSafety(
            tour: tour,
            vehicle: tesla,
            startingBatteryPercent: 0.30,
            conditions: .standard
        )

        let safeInCold = planner.validateTourSafety(
            tour: tour,
            vehicle: tesla,
            startingBatteryPercent: 0.30,
            conditions: DrivingConditions(temperatureFahrenheit: 20.0)
        )

        // Assert - may be safe in standard but not in cold
        #expect(!safeInCold || safeInStandard)
    }
}

@Suite("Tour Planning with Charger Placement", .tags(.medium))
struct TourPlanningTests {
    let planner = StandardTourPlanner()
    let tesla = EVProfile(
        make: "Tesla",
        model: "Model 3",
        year: 2024,
        batteryCapacityKWh: 75.0,
        chargingPorts: [.nacs],
        estimatedRangeMiles: 272.0,
        consumptionRateKWhPerMile: 0.276
    )

    @Test("Creates safe tour without adding chargers")
    func testSafeTourWithoutChargers() async throws {
        // Arrange
        let pois = [
            POI(
                name: "Stop 1",
                category: .park,
                location: GeoLocation(latitude: 45.5152, longitude: -122.6784)
            ),
            POI(
                name: "Stop 2",
                category: .museum,
                location: GeoLocation(latitude: 45.5762, longitude: -122.1153) // ~30 miles
            )
        ]
        let repository = InMemoryPOIRepository()

        // Act
        let result = try await planner.createTour(
            name: "Short Tour",
            pois: pois,
            vehicle: tesla,
            startingBatteryPercent: 0.80,
            conditions: .standard,
            poiRepository: repository
        )

        // Assert
        #expect(result.isSafeWithoutChargers)
        #expect(!result.chargersAdded)
        #expect(result.chargingStopsCount == 0)
        #expect(result.tour.isSafeForVehicle)
    }

    @Test("Adds chargers for long tour")
    func testLongTourAddsChargers() async throws {
        // Arrange - tour that needs charging
        let pois = [
            POI(
                name: "Portland",
                category: .attraction,
                location: GeoLocation(latitude: 45.5152, longitude: -122.6784)
            ),
            POI(
                name: "Crater Lake",
                category: .park,
                location: GeoLocation(latitude: 42.8684, longitude: -122.1685) // ~230 miles
            )
        ]

        // Add a charger along the route
        let charger = POI(
            name: "Midpoint Charger",
            category: .evCharger,
            location: GeoLocation(latitude: 44.0, longitude: -122.4)
        )
        let repository = InMemoryPOIRepository(initialPOIs: [charger])

        // Act - with low starting battery
        let result = try await planner.createTour(
            name: "Long Tour",
            pois: pois,
            vehicle: tesla,
            startingBatteryPercent: 0.60,
            conditions: .standard,
            poiRepository: repository
        )

        // Assert
        #expect(!result.isSafeWithoutChargers)
        #expect(result.chargersAdded)
        #expect(result.chargingStopsCount > 0)
    }

    @Test("Creates waypoints in correct order")
    func testWaypointOrdering() async throws {
        // Arrange
        let pois = [
            POI(
                name: "First",
                category: .park,
                location: GeoLocation(latitude: 45.5, longitude: -122.6)
            ),
            POI(
                name: "Second",
                category: .museum,
                location: GeoLocation(latitude: 45.6, longitude: -122.7)
            ),
            POI(
                name: "Third",
                category: .restaurant,
                location: GeoLocation(latitude: 45.7, longitude: -122.8)
            )
        ]
        let repository = InMemoryPOIRepository()

        // Act
        let result = try await planner.createTour(
            name: "Ordered Tour",
            pois: pois,
            vehicle: tesla,
            startingBatteryPercent: 0.80,
            conditions: .standard,
            poiRepository: repository
        )

        // Assert
        let waypoints = result.tour.orderedWaypoints
        #expect(waypoints.count == 3)
        #expect(waypoints[0].name == "First")
        #expect(waypoints[1].name == "Second")
        #expect(waypoints[2].name == "Third")
    }

    @Test("Calculates total tour distance")
    func testTotalDistanceCalculation() async throws {
        // Arrange
        let portland = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let multnomah = GeoLocation(latitude: 45.5762, longitude: -122.1153)

        let pois = [
            POI(name: "Portland", category: .attraction, location: portland),
            POI(name: "Multnomah Falls", category: .waterfall, location: multnomah)
        ]
        let repository = InMemoryPOIRepository()

        // Act
        let result = try await planner.createTour(
            name: "Distance Test",
            pois: pois,
            vehicle: tesla,
            startingBatteryPercent: 0.80,
            conditions: .standard,
            poiRepository: repository
        )

        // Assert
        #expect(result.tour.totalDistanceMiles > 0)
        let expectedDistance = portland.distance(to: multnomah)
        #expect(abs(result.tour.totalDistanceMiles - expectedDistance) < 1.0)
    }
}

@Suite("Charger Placement Logic", .tags(.medium))
struct ChargerPlacementTests {
    let planner = StandardTourPlanner()
    let tesla = EVProfile(
        make: "Tesla",
        model: "Model 3",
        year: 2024,
        batteryCapacityKWh: 75.0,
        chargingPorts: [.nacs],
        estimatedRangeMiles: 272.0,
        consumptionRateKWhPerMile: 0.276
    )

    @Test("Places charger between distant waypoints")
    func testChargerPlacementBetweenWaypoints() async throws {
        // Arrange - tour needing a charger
        let portland = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let craterLake = GeoLocation(latitude: 42.8684, longitude: -122.1685)

        let waypoints = [
            Waypoint(location: portland, name: "Portland", sequenceNumber: 0),
            Waypoint(location: craterLake, name: "Crater Lake", sequenceNumber: 1)
        ]

        let tour = Tour(
            name: "Long Tour",
            waypoints: waypoints,
            creatorId: UUID(),
            vehicleId: tesla.id
        )

        // Add charger near midpoint
        let charger = POI(
            name: "Midpoint Charger",
            category: .evCharger,
            location: GeoLocation(latitude: 44.0, longitude: -122.4)
        )
        let repository = InMemoryPOIRepository(initialPOIs: [charger])

        // Act
        let modifiedTour = try await planner.addChargingStops(
            to: tour,
            vehicle: tesla,
            startingBatteryPercent: 0.70,
            conditions: .standard,
            poiRepository: repository
        )

        // Assert
        #expect(modifiedTour.waypoints.count > tour.waypoints.count)
        #expect(modifiedTour.chargingStops.count > 0)
    }

    @Test("Renumbers waypoints after inserting chargers")
    func testWaypointRenumbering() async throws {
        // Arrange
        let location1 = GeoLocation(latitude: 45.5, longitude: -122.6)
        let location2 = GeoLocation(latitude: 42.8, longitude: -122.1)

        let waypoints = [
            Waypoint(location: location1, name: "Start", sequenceNumber: 0),
            Waypoint(location: location2, name: "End", sequenceNumber: 1)
        ]

        let tour = Tour(
            name: "Test Tour",
            waypoints: waypoints,
            creatorId: UUID(),
            vehicleId: tesla.id
        )

        let charger = POI(
            name: "Charger",
            category: .evCharger,
            location: GeoLocation(latitude: 44.0, longitude: -122.4)
        )
        let repository = InMemoryPOIRepository(initialPOIs: [charger])

        // Act
        let modifiedTour = try await planner.addChargingStops(
            to: tour,
            vehicle: tesla,
            startingBatteryPercent: 0.50,
            conditions: .standard,
            poiRepository: repository
        )

        // Assert - all waypoints should have sequential numbers
        let ordered = modifiedTour.orderedWaypoints
        for (index, waypoint) in ordered.enumerated() {
            #expect(waypoint.sequenceNumber == index)
        }
    }
}
