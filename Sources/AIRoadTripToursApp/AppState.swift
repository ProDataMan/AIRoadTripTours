import Foundation
import Observation
import AIRoadTripToursCore
import AIRoadTripToursServices

@Observable
@MainActor
public final class AppState {
    public var currentUser: User?
    public var currentVehicle: EVProfile?
    public var hasCompletedOnboarding: Bool = false

    /// POIs selected by the user for the audio tour
    public var selectedPOIs: Set<POI> = []

    public let poiRepository: POIRepository
    public let rangeEstimator: RangeEstimator
    private let storage: OnboardingStorage
    public let favoritesStorage = FavoritePOIsStorage()
    public let tourHistoryStorage = TourHistoryStorage()
    public let communityTourRepository = CommunityTourRepository()

    /// Shared audio tour manager that persists across navigation
    @available(iOS 17.0, macOS 14.0, *)
    public var audioTourManager: AudioTourManager {
        AudioTourManager(tourHistoryStorage: tourHistoryStorage)
    }

    public init() {
        // Initialize storage
        self.storage = OnboardingStorage()

        // Use live MapKit data for POI discovery
        #if canImport(MapKit)
        if #available(iOS 17.0, macOS 14.0, *) {
            self.poiRepository = MapKitPOIService()
        } else {
            // Fallback to in-memory for older OS versions
            self.poiRepository = InMemoryPOIRepository(initialPOIs: Self.fallbackPOIs)
        }
        #else
        self.poiRepository = InMemoryPOIRepository(initialPOIs: Self.fallbackPOIs)
        #endif

        self.rangeEstimator = SimpleRangeEstimator()

        // Load saved onboarding data
        loadOnboardingData()
    }

    // Fallback POIs for older OS versions or non-iOS platforms
    private static let fallbackPOIs: [POI] = [
        POI(
            name: "Multnomah Falls",
            description: "Oregon's tallest waterfall at 620 feet",
            category: .waterfall,
            location: GeoLocation(latitude: 45.5762, longitude: -122.1158),
            tags: ["nature", "hiking", "scenic"]
        ),
        POI(
            name: "Powell's City of Books",
            description: "World's largest independent bookstore",
            category: .shopping,
            location: GeoLocation(latitude: 45.5230, longitude: -122.6815),
            tags: ["books", "culture"]
        )
    ]

    public func completeOnboarding(user: User, vehicle: EVProfile) {
        self.currentUser = user
        self.currentVehicle = vehicle
        self.hasCompletedOnboarding = true

        // Persist to storage
        storage.saveUser(user)
        storage.saveVehicle(vehicle)
        storage.hasCompletedOnboarding = true
    }

    /// Load onboarding data from persistent storage.
    private func loadOnboardingData() {
        hasCompletedOnboarding = storage.hasCompletedOnboarding
        currentUser = storage.loadUser()
        currentVehicle = storage.loadVehicle()
    }

    /// Reset onboarding data (for testing or user logout).
    public func resetOnboarding() {
        storage.reset()
        currentUser = nil
        currentVehicle = nil
        hasCompletedOnboarding = false
    }
}
