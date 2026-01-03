import Testing
import Foundation
@testable import AIRoadTripToursCore

@Suite("User Profile Management", .tags(.small))
struct UserProfileTests {

    @Test("Creates user with valid email and display name")
    func testUserCreation() async throws {
        // Arrange & Act
        let user = User(
            email: "test@example.com",
            displayName: "Test User"
        )

        // Assert
        #expect(user.email == "test@example.com")
        #expect(user.displayName == "Test User")
        #expect(user.interests.isEmpty)
        #expect(user.vehicles.isEmpty)
        #expect(user.activeVehicleId == nil)
        #expect(!user.hasActiveSubscription)
    }

    @Test("Sets trial expiration to 90 days from creation")
    func testTrialPeriod() async throws {
        // Arrange
        let creationDate = Date()

        // Act
        let user = User(
            email: "test@example.com",
            displayName: "Test User",
            createdAt: creationDate
        )

        // Assert
        let expectedExpiration = Calendar.current.date(byAdding: .day, value: 90, to: creationDate)!
        let timeDifference = abs(user.trialExpiresAt.timeIntervalSince(expectedExpiration))
        #expect(timeDifference < 1.0) // Within 1 second
    }

    @Test("Reports trial as active within 90 days")
    func testTrialIsActive() async throws {
        // Arrange
        let recentDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!

        // Act
        let user = User(
            email: "test@example.com",
            displayName: "Test User",
            createdAt: recentDate
        )

        // Assert
        #expect(user.isTrialActive)
    }

    @Test("Reports trial as expired after 90 days")
    func testTrialExpired() async throws {
        // Arrange
        let oldDate = Calendar.current.date(byAdding: .day, value: -91, to: Date())!

        // Act
        let user = User(
            email: "test@example.com",
            displayName: "Test User",
            createdAt: oldDate
        )

        // Assert
        #expect(!user.isTrialActive)
    }

    @Test("Grants premium access during trial period")
    func testPremiumAccessDuringTrial() async throws {
        // Arrange
        let user = User(
            email: "test@example.com",
            displayName: "Test User"
        )

        // Assert
        #expect(user.hasPremiumAccess)
        #expect(user.isTrialActive)
    }

    @Test("Grants premium access with active subscription")
    func testPremiumAccessWithSubscription() async throws {
        // Arrange
        let expiredTrialDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let user = User(
            email: "test@example.com",
            displayName: "Test User",
            createdAt: expiredTrialDate,
            hasActiveSubscription: true
        )

        // Assert
        #expect(user.hasPremiumAccess)
        #expect(!user.isTrialActive)
        #expect(user.hasActiveSubscription)
    }

    @Test("Denies premium access after trial without subscription")
    func testNoPremiumAccessAfterTrial() async throws {
        // Arrange
        let expiredTrialDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let user = User(
            email: "test@example.com",
            displayName: "Test User",
            createdAt: expiredTrialDate,
            hasActiveSubscription: false
        )

        // Assert
        #expect(!user.hasPremiumAccess)
    }

    @Test("Adds interests to user profile")
    func testAddInterests() async throws {
        // Arrange
        var user = User(
            email: "test@example.com",
            displayName: "Test User"
        )
        let interest = UserInterest(name: "Hiking", category: .adventure)

        // Act
        user.interests.insert(interest)

        // Assert
        #expect(user.interests.count == 1)
        #expect(user.interests.contains(interest))
    }

    @Test("Adds vehicle to user profile")
    func testAddVehicle() async throws {
        // Arrange
        var user = User(
            email: "test@example.com",
            displayName: "Test User"
        )
        let vehicle = EVProfile(
            make: "Tesla",
            model: "Model 3",
            year: 2024,
            batteryCapacityKWh: 75.0,
            chargingPorts: [.nacs],
            estimatedRangeMiles: 272.0,
            consumptionRateKWhPerMile: 0.276
        )

        // Act
        user.vehicles.append(vehicle)

        // Assert
        #expect(user.vehicles.count == 1)
        #expect(user.vehicles[0].make == "Tesla")
    }

    @Test("Sets and retrieves active vehicle")
    func testActiveVehicle() async throws {
        // Arrange
        var user = User(
            email: "test@example.com",
            displayName: "Test User"
        )
        let vehicle = EVProfile(
            make: "Tesla",
            model: "Model 3",
            year: 2024,
            batteryCapacityKWh: 75.0,
            chargingPorts: [.nacs],
            estimatedRangeMiles: 272.0,
            consumptionRateKWhPerMile: 0.276
        )
        user.vehicles.append(vehicle)

        // Act
        user.activeVehicleId = vehicle.id

        // Assert
        #expect(user.activeVehicle?.id == vehicle.id)
        #expect(user.activeVehicle?.make == "Tesla")
    }

    @Test("Returns nil for active vehicle when none set")
    func testNoActiveVehicle() async throws {
        // Arrange
        let user = User(
            email: "test@example.com",
            displayName: "Test User"
        )

        // Assert
        #expect(user.activeVehicle == nil)
    }

    @Test("Updates user profile timestamp")
    func testUpdateTimestamp() async throws {
        // Arrange
        var user = User(
            email: "test@example.com",
            displayName: "Test User"
        )
        let originalUpdate = user.updatedAt

        // Act
        try await Task.sleep(for: .milliseconds(10))
        user.updatedAt = Date()

        // Assert
        #expect(user.updatedAt > originalUpdate)
    }
}

extension Tag {
    @Tag static var small: Self
    @Tag static var medium: Self
    @Tag static var large: Self
}
