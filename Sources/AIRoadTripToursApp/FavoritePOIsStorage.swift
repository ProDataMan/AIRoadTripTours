import Foundation
import AIRoadTripToursCore

/// Storage for managing favorite POIs using UserDefaults.
@MainActor
public final class FavoritePOIsStorage {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let favoritePOIIds = "favoritePOIIds"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Load favorite POI IDs.
    public func loadFavorites() -> Set<UUID> {
        guard let data = userDefaults.data(forKey: Keys.favoritePOIIds) else {
            return []
        }

        do {
            return try decoder.decode(Set<UUID>.self, from: data)
        } catch {
            print("Error loading favorites: \(error)")
            return []
        }
    }

    /// Save favorite POI IDs.
    public func saveFavorites(_ favorites: Set<UUID>) {
        do {
            let data = try encoder.encode(favorites)
            userDefaults.set(data, forKey: Keys.favoritePOIIds)
        } catch {
            print("Error saving favorites: \(error)")
        }
    }

    /// Add POI to favorites.
    public func addFavorite(_ poiId: UUID) {
        var favorites = loadFavorites()
        favorites.insert(poiId)
        saveFavorites(favorites)
    }

    /// Remove POI from favorites.
    public func removeFavorite(_ poiId: UUID) {
        var favorites = loadFavorites()
        favorites.remove(poiId)
        saveFavorites(favorites)
    }

    /// Toggle POI favorite status.
    public func toggleFavorite(_ poiId: UUID) {
        var favorites = loadFavorites()
        if favorites.contains(poiId) {
            favorites.remove(poiId)
        } else {
            favorites.insert(poiId)
        }
        saveFavorites(favorites)
    }

    /// Check if POI is favorited.
    public func isFavorite(_ poiId: UUID) -> Bool {
        loadFavorites().contains(poiId)
    }

    /// Clear all favorites.
    public func clearAll() {
        userDefaults.removeObject(forKey: Keys.favoritePOIIds)
    }
}
