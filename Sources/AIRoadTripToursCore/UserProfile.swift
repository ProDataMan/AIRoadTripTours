import Foundation

/// Defines the contract for a user profile.
public protocol UserProfile: Identifiable, Codable, Sendable {
    /// Unique identifier for the user.
    var id: UUID { get }

    /// User's email address.
    var email: String { get }

    /// User's display name.
    var displayName: String { get }

    /// User's selected interests for tour personalization.
    var interests: Set<UserInterest> { get set }

    /// User's registered vehicles.
    var vehicles: [EVProfile] { get set }

    /// Currently active vehicle for trip planning.
    var activeVehicleId: UUID? { get set }

    /// Account creation timestamp.
    var createdAt: Date { get }

    /// Last profile update timestamp.
    var updatedAt: Date { get set }

    /// Trial expiration date (90 days from creation).
    var trialExpiresAt: Date { get }

    /// Whether the user has an active subscription.
    var hasActiveSubscription: Bool { get }
}

/// Concrete implementation of a user profile.
public struct User: UserProfile {
    public let id: UUID
    public let email: String
    public var displayName: String
    public var interests: Set<UserInterest>
    public var vehicles: [EVProfile]
    public var activeVehicleId: UUID?
    public let createdAt: Date
    public var updatedAt: Date
    public let trialExpiresAt: Date
    public var hasActiveSubscription: Bool

    public init(
        id: UUID = UUID(),
        email: String,
        displayName: String,
        interests: Set<UserInterest> = [],
        vehicles: [EVProfile] = [],
        activeVehicleId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        hasActiveSubscription: Bool = false
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.interests = interests
        self.vehicles = vehicles
        self.activeVehicleId = activeVehicleId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.trialExpiresAt = Calendar.current.date(byAdding: .day, value: 90, to: createdAt) ?? createdAt
        self.hasActiveSubscription = hasActiveSubscription
    }

    /// Returns the currently active vehicle, if set.
    public var activeVehicle: EVProfile? {
        guard let activeVehicleId else { return nil }
        return vehicles.first { $0.id == activeVehicleId }
    }

    /// Checks if the user's trial period is still active.
    public var isTrialActive: Bool {
        Date() < trialExpiresAt
    }

    /// Checks if the user has premium access (trial or subscription).
    public var hasPremiumAccess: Bool {
        isTrialActive || hasActiveSubscription
    }
}
