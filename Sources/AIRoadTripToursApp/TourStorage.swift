import Foundation
import AIRoadTripToursCore

@MainActor
public final class TourStorage {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let savedTours = "savedTours"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func loadTours() -> [Tour] {
        guard let data = userDefaults.data(forKey: Keys.savedTours) else {
            return []
        }

        do {
            return try decoder.decode([Tour].self, from: data)
        } catch {
            print("Error loading tours: \(error)")
            return []
        }
    }

    public func saveTours(_ tours: [Tour]) {
        do {
            let data = try encoder.encode(tours)
            userDefaults.set(data, forKey: Keys.savedTours)
        } catch {
            print("Error saving tours: \(error)")
        }
    }

    public func addTour(_ tour: Tour) {
        var tours = loadTours()
        tours.append(tour)
        saveTours(tours)
    }

    public func updateTour(_ tour: Tour) {
        var tours = loadTours()
        if let index = tours.firstIndex(where: { $0.id == tour.id }) {
            tours[index] = tour
            saveTours(tours)
        }
    }

    public func deleteTour(_ tour: Tour) {
        var tours = loadTours()
        tours.removeAll { $0.id == tour.id }
        saveTours(tours)
    }

    public func clearAll() {
        userDefaults.removeObject(forKey: Keys.savedTours)
    }
}
