import Foundation
import AIRoadTripToursCore

/// Storage for managing tour history and statistics.
@MainActor
public final class TourHistoryStorage {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let tourHistory = "tourHistory"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Load tour history entries.
    public func loadHistory() -> [TourHistoryEntry] {
        guard let data = userDefaults.data(forKey: Keys.tourHistory) else {
            return []
        }

        do {
            return try decoder.decode([TourHistoryEntry].self, from: data)
        } catch {
            print("Error loading tour history: \(error)")
            return []
        }
    }

    /// Save tour history entries.
    public func saveHistory(_ entries: [TourHistoryEntry]) {
        do {
            let data = try encoder.encode(entries)
            userDefaults.set(data, forKey: Keys.tourHistory)
        } catch {
            print("Error saving tour history: \(error)")
        }
    }

    /// Add a completed tour to history.
    public func addEntry(_ entry: TourHistoryEntry) {
        var history = loadHistory()
        history.append(entry)
        saveHistory(history)
    }

    /// Get recent tour history (last N entries).
    public func getRecentHistory(limit: Int = 10) -> [TourHistoryEntry] {
        let history = loadHistory()
        return Array(history.suffix(limit).reversed())
    }

    /// Compute aggregate statistics from tour history.
    public func computeStatistics() -> TourStatistics {
        let history = loadHistory()

        guard !history.isEmpty else {
            return .empty
        }

        let totalToursCompleted = history.count
        let totalDistanceMiles = history.reduce(0.0) { $0 + $1.distanceMiles }
        let totalPOIsVisited = history.reduce(0) { $0 + $1.poisVisited }
        let totalTimeMinutes = history.reduce(0) { $0 + $1.durationMinutes }

        let sortedByDate = history.sorted { $0.completedAt < $1.completedAt }
        let firstTourDate = sortedByDate.first?.completedAt
        let lastTourDate = sortedByDate.last?.completedAt

        let longestTourMiles = history.map { $0.distanceMiles }.max() ?? 0.0
        let mostPOIsInOneTour = history.map { $0.poisVisited }.max() ?? 0

        // Placeholder for favorite categories (would need POI category data)
        let favoritePOICategories: [String] = []

        return TourStatistics(
            totalToursCompleted: totalToursCompleted,
            totalDistanceMiles: totalDistanceMiles,
            totalPOIsVisited: totalPOIsVisited,
            totalTimeMinutes: totalTimeMinutes,
            firstTourDate: firstTourDate,
            lastTourDate: lastTourDate,
            favoritePOICategories: favoritePOICategories,
            longestTourMiles: longestTourMiles,
            mostPOIsInOneTour: mostPOIsInOneTour
        )
    }

    /// Delete a specific history entry.
    public func deleteEntry(_ entry: TourHistoryEntry) {
        var history = loadHistory()
        history.removeAll { $0.id == entry.id }
        saveHistory(history)
    }

    /// Clear all tour history.
    public func clearAll() {
        userDefaults.removeObject(forKey: Keys.tourHistory)
    }
}
