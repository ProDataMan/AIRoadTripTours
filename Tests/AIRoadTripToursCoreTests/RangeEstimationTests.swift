import Testing
import Foundation
@testable import AIRoadTripToursCore

@Suite("Vehicle Profile and Range Estimation", .tags(.small))
struct VehicleTests {

    @Test("Creates EV profile with valid specifications")
    func testEVProfileCreation() async throws {
        // Arrange & Act
        let vehicle = EVProfile(
            make: "Tesla",
            model: "Model 3",
            year: 2024,
            batteryCapacityKWh: 75.0,
            chargingPorts: [.nacs, .ccs],
            estimatedRangeMiles: 272.0,
            consumptionRateKWhPerMile: 0.276
        )

        // Assert
        #expect(vehicle.make == "Tesla")
        #expect(vehicle.model == "Model 3")
        #expect(vehicle.year == 2024)
        #expect(vehicle.batteryCapacityKWh == 75.0)
        #expect(vehicle.chargingPorts.contains(.nacs))
        #expect(vehicle.estimatedRangeMiles == 272.0)
    }

    @Test("Supports multiple charging port types")
    func testMultipleChargingPorts() async throws {
        // Arrange & Act
        let vehicle = EVProfile(
            make: "Ford",
            model: "Mustang Mach-E",
            year: 2024,
            batteryCapacityKWh: 91.0,
            chargingPorts: [.ccs, .j1772],
            estimatedRangeMiles: 312.0,
            consumptionRateKWhPerMile: 0.291
        )

        // Assert
        #expect(vehicle.chargingPorts.count == 2)
        #expect(vehicle.chargingPorts.contains(.ccs))
        #expect(vehicle.chargingPorts.contains(.j1772))
    }
}

@Suite("Range Estimation - Standard Conditions", .tags(.small))
struct RangeEstimationStandardTests {
    let estimator = SimpleRangeEstimator()
    let testVehicle = EVProfile(
        make: "Tesla",
        model: "Model 3",
        year: 2024,
        batteryCapacityKWh: 75.0,
        chargingPorts: [.nacs],
        estimatedRangeMiles: 272.0,
        consumptionRateKWhPerMile: 0.276
    )

    @Test("Calculates range at full battery")
    func testFullBatteryRange() async throws {
        // Act
        let range = estimator.estimateRange(
            for: testVehicle,
            currentBatteryPercent: 1.0,
            conditions: .standard
        )

        // Assert
        #expect(range > 250) // Should be close to EPA rating minus conditions
        #expect(range <= testVehicle.estimatedRangeMiles)
    }

    @Test("Calculates range at 50% battery")
    func testHalfBatteryRange() async throws {
        // Act
        let range = estimator.estimateRange(
            for: testVehicle,
            currentBatteryPercent: 0.5,
            conditions: .standard
        )

        // Assert
        let expectedRange = testVehicle.estimatedRangeMiles * 0.5
        #expect(range > expectedRange * 0.9) // Within 10%
        #expect(range <= expectedRange)
    }

    @Test("Calculates range at 20% battery")
    func testLowBatteryRange() async throws {
        // Act
        let range = estimator.estimateRange(
            for: testVehicle,
            currentBatteryPercent: 0.2,
            conditions: .standard
        )

        // Assert
        let expectedRange = testVehicle.estimatedRangeMiles * 0.2
        #expect(range > 40) // Should be around 54 miles
        #expect(range <= expectedRange)
    }

    @Test("Trip is safe with sufficient battery")
    func testSafeTripWithSufficientBattery() async throws {
        // Act
        let isSafe = estimator.isTripSafe(
            vehicle: testVehicle,
            currentBatteryPercent: 0.8,
            distanceMiles: 100.0,
            conditions: .standard
        )

        // Assert
        #expect(isSafe)
    }

    @Test("Trip is unsafe with insufficient battery")
    func testUnsafeTripWithInsufficientBattery() async throws {
        // Act
        let isSafe = estimator.isTripSafe(
            vehicle: testVehicle,
            currentBatteryPercent: 0.3,
            distanceMiles: 100.0,
            conditions: .standard
        )

        // Assert
        #expect(!isSafe)
    }
}

@Suite("Range Estimation - Cold Weather", .tags(.small))
struct RangeEstimationColdWeatherTests {
    let estimator = SimpleRangeEstimator()
    let testVehicle = EVProfile(
        make: "Tesla",
        model: "Model 3",
        year: 2024,
        batteryCapacityKWh: 75.0,
        chargingPorts: [.nacs],
        estimatedRangeMiles: 272.0,
        consumptionRateKWhPerMile: 0.276
    )

    @Test("Reduces range in cold weather")
    func testColdWeatherRangeReduction() async throws {
        // Arrange
        let standardConditions = DrivingConditions.standard
        let coldConditions = DrivingConditions(temperatureFahrenheit: 20.0)

        // Act
        let standardRange = estimator.estimateRange(
            for: testVehicle,
            currentBatteryPercent: 1.0,
            conditions: standardConditions
        )
        let coldRange = estimator.estimateRange(
            for: testVehicle,
            currentBatteryPercent: 1.0,
            conditions: coldConditions
        )

        // Assert
        #expect(coldRange < standardRange)
        let reductionPercent = (standardRange - coldRange) / standardRange
        #expect(reductionPercent > 0.3) // At least 30% reduction at 20°F
    }

    @Test("Accounts for cold soak energy loss")
    func testColdSoakEnergyLoss() async throws {
        // Arrange
        let noColdSoak = DrivingConditions(temperatureFahrenheit: 20.0)
        let withColdSoak = DrivingConditions(
            temperatureFahrenheit: 20.0,
            includesColdSoak: true,
            coldSoakHours: 8.0
        )

        // Act
        let rangeNoColdSoak = estimator.estimateRange(
            for: testVehicle,
            currentBatteryPercent: 1.0,
            conditions: noColdSoak
        )
        let rangeWithColdSoak = estimator.estimateRange(
            for: testVehicle,
            currentBatteryPercent: 1.0,
            conditions: withColdSoak
        )

        // Assert
        #expect(rangeWithColdSoak < rangeNoColdSoak)
        let rangeLoss = rangeNoColdSoak - rangeWithColdSoak
        #expect(rangeLoss > 30) // Should lose significant range from 8hr cold soak
    }

    @Test("Requires higher battery percentage for cold weather trips")
    func testColdWeatherBatteryRequirement() async throws {
        // Arrange
        let standardConditions = DrivingConditions.standard
        let coldConditions = DrivingConditions(temperatureFahrenheit: 20.0)
        let tripDistance = 100.0

        // Act
        let standardRequired = estimator.requiredBatteryForTrip(
            vehicle: testVehicle,
            distanceMiles: tripDistance,
            conditions: standardConditions
        )
        let coldRequired = estimator.requiredBatteryForTrip(
            vehicle: testVehicle,
            distanceMiles: tripDistance,
            conditions: coldConditions
        )

        // Assert
        #expect(coldRequired > standardRequired)
    }
}

@Suite("Range Estimation - Elevation Changes", .tags(.small))
struct RangeEstimationElevationTests {
    let estimator = SimpleRangeEstimator()
    let testVehicle = EVProfile(
        make: "Tesla",
        model: "Model 3",
        year: 2024,
        batteryCapacityKWh: 75.0,
        chargingPorts: [.nacs],
        estimatedRangeMiles: 272.0,
        consumptionRateKWhPerMile: 0.276
    )

    @Test("Reduces range for significant elevation gain")
    func testElevationGainRangeReduction() async throws {
        // Arrange
        let flatConditions = DrivingConditions.standard
        let hillConditions = DrivingConditions(elevationChangeFeet: 3000.0)

        // Act
        let flatRange = estimator.estimateRange(
            for: testVehicle,
            currentBatteryPercent: 1.0,
            conditions: flatConditions
        )
        let hillRange = estimator.estimateRange(
            for: testVehicle,
            currentBatteryPercent: 1.0,
            conditions: hillConditions
        )

        // Assert
        #expect(hillRange < flatRange)
        let reductionPercent = (flatRange - hillRange) / flatRange
        #expect(reductionPercent > 0.05) // At least 5% reduction for 3000ft elevation
    }

    @Test("Accounts for elevation in trip safety calculation")
    func testElevationInTripSafety() async throws {
        // Arrange
        let flatConditions = DrivingConditions.standard
        let mountainConditions = DrivingConditions(elevationChangeFeet: 6000.0)
        let tripDistance = 100.0

        // Act
        let requiredBatteryFlat = estimator.requiredBatteryForTrip(
            vehicle: testVehicle,
            distanceMiles: tripDistance,
            conditions: flatConditions
        )
        let requiredBatteryMountain = estimator.requiredBatteryForTrip(
            vehicle: testVehicle,
            distanceMiles: tripDistance,
            conditions: mountainConditions
        )

        // Assert - mountains require more battery than flat terrain
        #expect(requiredBatteryMountain > requiredBatteryFlat)
    }
}

@Suite("Range Estimation - Safety Buffer", .tags(.small))
struct RangeEstimationSafetyBufferTests {
    let testVehicle = EVProfile(
        make: "Tesla",
        model: "Model 3",
        year: 2024,
        batteryCapacityKWh: 75.0,
        chargingPorts: [.nacs],
        estimatedRangeMiles: 272.0,
        consumptionRateKWhPerMile: 0.276
    )

    @Test("Applies safety buffer to required battery")
    func testSafetyBuffer() async throws {
        // Arrange
        let estimator = SimpleRangeEstimator(safetyBufferPercent: 0.15)
        let tripDistance = 100.0

        // Act
        let requiredBattery = estimator.requiredBatteryForTrip(
            vehicle: testVehicle,
            distanceMiles: tripDistance,
            conditions: .standard
        )

        // Calculate expected without buffer
        let baseEnergyKWh = tripDistance * testVehicle.consumptionRateKWhPerMile
        let baseRequiredPercent = baseEnergyKWh / testVehicle.batteryCapacityKWh

        // Assert - required should be higher than base due to buffer
        #expect(requiredBattery > baseRequiredPercent)
    }

    @Test("Custom safety buffer affects trip safety")
    func testCustomSafetyBuffer() async throws {
        // Arrange
        let conservativeEstimator = SimpleRangeEstimator(safetyBufferPercent: 0.25)
        let aggressiveEstimator = SimpleRangeEstimator(safetyBufferPercent: 0.05)

        // Act
        let conservativeSafe = conservativeEstimator.isTripSafe(
            vehicle: testVehicle,
            currentBatteryPercent: 0.5,
            distanceMiles: 90.0,
            conditions: .standard
        )
        let aggressiveSafe = aggressiveEstimator.isTripSafe(
            vehicle: testVehicle,
            currentBatteryPercent: 0.5,
            distanceMiles: 90.0,
            conditions: .standard
        )

        // Assert - aggressive buffer may allow trip that conservative buffer rejects
        #expect(aggressiveSafe || !conservativeSafe)
    }
}
