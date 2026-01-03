import Foundation
import AIRoadTripToursCore

/// Manages persistent storage of onboarding data.
@MainActor
public final class OnboardingStorage {

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let currentUser = "currentUser"
        static let currentVehicle = "currentVehicle"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Onboarding Status

    /// Check if user has completed onboarding.
    public var hasCompletedOnboarding: Bool {
        get {
            userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.hasCompletedOnboarding)
        }
    }

    // MARK: - User Data

    /// Load saved user data.
    public func loadUser() -> User? {
        guard let data = userDefaults.data(forKey: Keys.currentUser) else {
            return nil
        }

        return try? decoder.decode(User.self, from: data)
    }

    /// Save user data.
    public func saveUser(_ user: User) {
        guard let data = try? encoder.encode(user) else {
            return
        }

        userDefaults.set(data, forKey: Keys.currentUser)
    }

    /// Clear user data.
    public func clearUser() {
        userDefaults.removeObject(forKey: Keys.currentUser)
    }

    // MARK: - Vehicle Data

    /// Load saved vehicle data.
    public func loadVehicle() -> EVProfile? {
        guard let data = userDefaults.data(forKey: Keys.currentVehicle) else {
            return nil
        }

        return try? decoder.decode(EVProfile.self, from: data)
    }

    /// Save vehicle data.
    public func saveVehicle(_ vehicle: EVProfile) {
        guard let data = try? encoder.encode(vehicle) else {
            return
        }

        userDefaults.set(data, forKey: Keys.currentVehicle)
    }

    /// Clear vehicle data.
    public func clearVehicle() {
        userDefaults.removeObject(forKey: Keys.currentVehicle)
    }

    // MARK: - Reset

    /// Clear all onboarding data.
    public func reset() {
        hasCompletedOnboarding = false
        clearUser()
        clearVehicle()
    }
}
