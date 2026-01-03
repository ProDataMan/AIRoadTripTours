import Foundation

/// Defines the contract for a vehicle profile.
public protocol Vehicle: Identifiable, Codable, Sendable {
    /// Unique identifier for the vehicle.
    var id: UUID { get }

    /// Vehicle manufacturer.
    var make: String { get }

    /// Vehicle model name.
    var model: String { get }

    /// Model year.
    var year: Int { get }

    /// Battery capacity in kilowatt-hours (kWh).
    var batteryCapacityKWh: Double { get }

    /// Charging port type(s) supported.
    var chargingPorts: Set<ChargingPortType> { get }

    /// Estimated range in miles on full charge (EPA rating).
    var estimatedRangeMiles: Double { get }

    /// Energy consumption rate in kWh per mile.
    var consumptionRateKWhPerMile: Double { get }
}

/// Types of EV charging ports.
public enum ChargingPortType: String, Codable, Sendable, CaseIterable {
    case tesla = "Tesla"
    case ccs = "CCS" // Combined Charging System
    case chademo = "CHAdeMO"
    case j1772 = "J1772" // Level 1 & 2
    case nacs = "NACS" // North American Charging Standard (Tesla became standard)
}

/// Concrete implementation of a vehicle profile.
public struct EVProfile: Vehicle {
    public let id: UUID
    public let make: String
    public let model: String
    public let year: Int
    public let batteryCapacityKWh: Double
    public let chargingPorts: Set<ChargingPortType>
    public let estimatedRangeMiles: Double
    public let consumptionRateKWhPerMile: Double

    public init(
        id: UUID = UUID(),
        make: String,
        model: String,
        year: Int,
        batteryCapacityKWh: Double,
        chargingPorts: Set<ChargingPortType>,
        estimatedRangeMiles: Double,
        consumptionRateKWhPerMile: Double
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.batteryCapacityKWh = batteryCapacityKWh
        self.chargingPorts = chargingPorts
        self.estimatedRangeMiles = estimatedRangeMiles
        self.consumptionRateKWhPerMile = consumptionRateKWhPerMile
    }
}
