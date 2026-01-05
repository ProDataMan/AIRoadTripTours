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

    // Lazy-loaded repositories for faster startup
    private var _poiRepository: POIRepository?
    public var poiRepository: POIRepository {
        if let repo = _poiRepository {
            return repo
        }
        let repo = createPOIRepository()
        _poiRepository = repo
        return repo
    }

    public let rangeEstimator: RangeEstimator
    private let storage: OnboardingStorage
    public let tourStorage = TourStorage()
    public let favoritesStorage = FavoritePOIsStorage()
    public let tourHistoryStorage = TourHistoryStorage()
    public let communityTourRepository = CommunityTourRepository()

    // Offline support services
    public let audioCache: AudioCacheStorage
    public let offlinePackageStorage: OfflineTourPackageStorage
    public let networkMonitor: NetworkConnectivityMonitor
    public let offlineDownloadManager: OfflineTourDownloadManager

    /// Saved tours for offline downloads
    public var savedTours: [Tour] {
        tourStorage.loadTours()
    }

    /// Shared audio tour manager that persists across navigation
    @available(iOS 17.0, macOS 14.0, *)
    public var audioTourManager: AudioTourManager {
        AudioTourManager(tourHistoryStorage: tourHistoryStorage)
    }

    public init() {
        print("AppState: Initializing...")
        let startTime = Date()

        // Initialize storage - fast
        self.storage = OnboardingStorage()
        self.rangeEstimator = SimpleRangeEstimator()

        // Initialize offline support services
        do {
            self.audioCache = try AudioCacheStorage()
            self.offlinePackageStorage = try OfflineTourPackageStorage()
        } catch {
            print("Error initializing offline storage: \(error)")
            fatalError("Failed to initialize offline storage: \(error)")
        }

        self.networkMonitor = NetworkConnectivityMonitor()
        self.offlineDownloadManager = OfflineTourDownloadManager(
            audioCache: audioCache,
            packageStorage: offlinePackageStorage,
            networkMonitor: networkMonitor
        )

        // Load saved onboarding data - fast
        loadOnboardingData()

        // Defer POI repository creation until first access
        // This avoids MapKit initialization during app launch

        let elapsed = Date().timeIntervalSince(startTime)
        print("AppState: Initialized in \(elapsed) seconds")
    }

    private func createPOIRepository() -> POIRepository {
        print("AppState: Creating POI repository...")
        let startTime = Date()

        let repo: POIRepository
        #if canImport(MapKit)
        if #available(iOS 17.0, macOS 14.0, *) {
            repo = MapKitPOIService()
        } else {
            repo = InMemoryPOIRepository(initialPOIs: Self.fallbackPOIs)
        }
        #else
        repo = InMemoryPOIRepository(initialPOIs: Self.fallbackPOIs)
        #endif

        let elapsed = Date().timeIntervalSince(startTime)
        print("AppState: POI repository created in \(elapsed) seconds")
        return repo
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
