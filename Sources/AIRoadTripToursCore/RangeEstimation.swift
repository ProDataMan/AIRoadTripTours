import Foundation

/// Defines the contract for range estimation calculations.
public protocol RangeEstimator: Sendable {
    /// Calculates remaining range based on current battery level and conditions.
    ///
    /// - Parameters:
    ///   - vehicle: The vehicle profile
    ///   - currentBatteryPercent: Current battery level (0.0 to 1.0)
    ///   - conditions: Environmental and driving conditions
    /// - Returns: Estimated remaining range in miles
    func estimateRange(
        for vehicle: any Vehicle,
        currentBatteryPercent: Double,
        conditions: DrivingConditions
    ) -> Double

    /// Calculates energy required for a trip including safety buffer.
    ///
    /// - Parameters:
    ///   - vehicle: The vehicle profile
    ///   - distanceMiles: Total trip distance in miles
    ///   - conditions: Environmental and driving conditions
    /// - Returns: Required battery percentage (0.0 to 1.0) including safety buffer
    func requiredBatteryForTrip(
        vehicle: any Vehicle,
        distanceMiles: Double,
        conditions: DrivingConditions
    ) -> Double

    /// Determines if a trip is safe given current battery level.
    ///
    /// - Parameters:
    ///   - vehicle: The vehicle profile
    ///   - currentBatteryPercent: Current battery level (0.0 to 1.0)
    ///   - distanceMiles: Total trip distance in miles
    ///   - conditions: Environmental and driving conditions
    /// - Returns: True if trip can be completed safely with buffer
    func isTripSafe(
        vehicle: any Vehicle,
        currentBatteryPercent: Double,
        distanceMiles: Double,
        conditions: DrivingConditions
    ) -> Bool
}

/// Environmental and driving conditions affecting range.
public struct DrivingConditions: Codable, Sendable {
    /// Temperature in Fahrenheit.
    public let temperatureFahrenheit: Double

    /// Whether vehicle will be parked in cold weather during trip.
    public let includesColdSoak: Bool

    /// Estimated cold soak duration in hours.
    public let coldSoakHours: Double

    /// Average elevation gain/loss in feet.
    public let elevationChangeFeet: Double

    /// Average speed in miles per hour.
    public let averageSpeedMph: Double

    public init(
        temperatureFahrenheit: Double = 70.0,
        includesColdSoak: Bool = false,
        coldSoakHours: Double = 0.0,
        elevationChangeFeet: Double = 0.0,
        averageSpeedMph: Double = 55.0
    ) {
        self.temperatureFahrenheit = temperatureFahrenheit
        self.includesColdSoak = includesColdSoak
        self.coldSoakHours = coldSoakHours
        self.elevationChangeFeet = elevationChangeFeet
        self.averageSpeedMph = averageSpeedMph
    }

    /// Standard conditions for baseline calculations.
    public static let standard = DrivingConditions()
}

/// Simple range estimator using EPA ratings with condition adjustments.
public struct SimpleRangeEstimator: RangeEstimator {
    /// Safety buffer percentage (default 15% reserve).
    public let safetyBufferPercent: Double

    /// Cold weather range reduction per degree below 65°F.
    private let coldWeatherFactor: Double = 0.01 // 1% per degree

    /// Cold soak energy loss per hour in kWh.
    private let coldSoakEnergyLossPerHour: Double = 1.5

    /// Elevation adjustment per 1000 feet.
    private let elevationFactor: Double = 0.02 // 2% per 1000 feet

    public init(safetyBufferPercent: Double = 0.15) {
        self.safetyBufferPercent = safetyBufferPercent
    }

    public func estimateRange(
        for vehicle: any Vehicle,
        currentBatteryPercent: Double,
        conditions: DrivingConditions
    ) -> Double {
        let baseRange = vehicle.estimatedRangeMiles * currentBatteryPercent
        return applyConditionAdjustments(baseRange: baseRange, vehicle: vehicle, conditions: conditions)
    }

    public func requiredBatteryForTrip(
        vehicle: any Vehicle,
        distanceMiles: Double,
        conditions: DrivingConditions
    ) -> Double {
        // Calculate base energy needed
        let baseEnergyKWh = distanceMiles * vehicle.consumptionRateKWhPerMile

        // Add cold soak energy loss
        var totalEnergyKWh = baseEnergyKWh
        if conditions.includesColdSoak && conditions.temperatureFahrenheit < 32 {
            totalEnergyKWh += conditions.coldSoakHours * coldSoakEnergyLossPerHour
        }

        // Apply temperature adjustment
        if conditions.temperatureFahrenheit < 65 {
            let tempDiff = 65 - conditions.temperatureFahrenheit
            totalEnergyKWh *= (1 + tempDiff * coldWeatherFactor)
        }

        // Apply elevation adjustment
        let elevationAdjustment = abs(conditions.elevationChangeFeet) / 1000.0 * elevationFactor
        totalEnergyKWh *= (1 + elevationAdjustment)

        // Convert to battery percentage and add safety buffer
        let requiredPercent = totalEnergyKWh / vehicle.batteryCapacityKWh
        return min(requiredPercent * (1 + safetyBufferPercent), 1.0)
    }

    public func isTripSafe(
        vehicle: any Vehicle,
        currentBatteryPercent: Double,
        distanceMiles: Double,
        conditions: DrivingConditions
    ) -> Bool {
        let requiredBattery = requiredBatteryForTrip(
            vehicle: vehicle,
            distanceMiles: distanceMiles,
            conditions: conditions
        )
        return currentBatteryPercent >= requiredBattery
    }

    private func applyConditionAdjustments(
        baseRange: Double,
        vehicle: any Vehicle,
        conditions: DrivingConditions
    ) -> Double {
        var adjustedRange = baseRange

        // Temperature adjustment
        if conditions.temperatureFahrenheit < 65 {
            let tempDiff = 65 - conditions.temperatureFahrenheit
            adjustedRange *= (1 - tempDiff * coldWeatherFactor)
        }

        // Cold soak adjustment
        if conditions.includesColdSoak && conditions.temperatureFahrenheit < 32 {
            let energyLostKWh = conditions.coldSoakHours * coldSoakEnergyLossPerHour
            let rangeLost = energyLostKWh / vehicle.consumptionRateKWhPerMile
            adjustedRange -= rangeLost
        }

        // Elevation adjustment
        let elevationAdjustment = abs(conditions.elevationChangeFeet) / 1000.0 * elevationFactor
        adjustedRange *= (1 - elevationAdjustment)

        return max(adjustedRange, 0)
    }
}
