import Testing
import Foundation
@testable import AIRoadTripToursCore

@Suite("POI Filtering Service", .tags(.small))
struct POIFilterServiceTests {
    let service = StandardPOIFilterService()
    let portland = GeoLocation(latitude: 45.5152, longitude: -122.6784)
    let seattle = GeoLocation(latitude: 47.6062, longitude: -122.3321)

    func createSamplePOIs() -> [POI] {
        [
            POI(
                name: "Multnomah Falls",
                description: "Waterfall",
                category: .waterfall,
                location: GeoLocation(latitude: 45.5762, longitude: -122.1153),
                rating: POIRating(averageRating: 4.8, totalRatings: 5000, priceLevel: 1),
                tags: ["scenic", "nature"]
            ),
            POI(
                name: "Portland Japanese Garden",
                category: .park,
                location: GeoLocation(latitude: 45.5195, longitude: -122.7057),
                rating: POIRating(averageRating: 4.7, totalRatings: 2000, priceLevel: 2),
                tags: ["garden", "peaceful"]
            ),
            POI(
                name: "Voodoo Doughnut",
                category: .restaurant,
                location: GeoLocation(latitude: 45.5228, longitude: -122.6731),
                rating: POIRating(averageRating: 4.2, totalRatings: 10000, priceLevel: 1),
                tags: ["famous", "dessert"]
            ),
            POI(
                name: "Pike Place Market",
                category: .attraction,
                location: seattle,
                rating: POIRating(averageRating: 4.6, totalRatings: 8000, priceLevel: 2),
                tags: ["shopping", "food"]
            ),
            POI(
                name: "Portland Supercharger",
                category: .evCharger,
                location: GeoLocation(latitude: 45.5100, longitude: -122.6700),
                source: .google
            )
        ]
    }

    @Test("Filters POIs by category")
    func testFilterByCategory() async throws {
        // Arrange
        let pois = createSamplePOIs()
        let filter = POIFilter(categories: [.restaurant, .cafe])

        // Act
        let results = service.filter(pois, using: filter, sortedBy: .name)

        // Assert
        #expect(results.count == 1)
        #expect(results[0].name == "Voodoo Doughnut")
    }

    @Test("Filters POIs by user interests")
    func testFilterByInterests() async throws {
        // Arrange
        let pois = createSamplePOIs()
        let interests: Set<UserInterest> = [
            UserInterest(name: "Nature", category: .nature),
            UserInterest(name: "Adventure", category: .adventure)
        ]
        let filter = POIFilter(interests: interests)

        // Act
        let results = service.filter(pois, using: filter, sortedBy: .name)

        // Assert
        #expect(results.count >= 2) // Multnomah Falls, Portland Japanese Garden
        let names = results.map { $0.name }
        #expect(names.contains("Multnomah Falls"))
        #expect(names.contains("Portland Japanese Garden"))
    }

    @Test("Filters POIs by location radius")
    func testFilterByLocationRadius() async throws {
        // Arrange
        let pois = createSamplePOIs()
        let filter = POIFilter(
            location: portland,
            radiusMiles: 5.0
        )

        // Act
        let results = service.filter(pois, using: filter, sortedBy: .distance)

        // Assert
        // Should exclude Seattle (Pike Place Market)
        #expect(!results.contains(where: { $0.name == "Pike Place Market" }))
        // Should include Portland POIs
        #expect(results.contains(where: { $0.name == "Voodoo Doughnut" }))
    }

    @Test("Filters POIs by minimum rating")
    func testFilterByMinimumRating() async throws {
        // Arrange
        let pois = createSamplePOIs()
        let filter = POIFilter(minimumRating: 4.5)

        // Act
        let results = service.filter(pois, using: filter, sortedBy: .rating)

        // Assert
        #expect(results.allSatisfy { poi in
            guard let rating = poi.rating else { return false }
            return rating.averageRating >= 4.5
        })
        #expect(results.count == 3) // Multnomah Falls, Japanese Garden, Pike Place
    }

    @Test("Filters POIs by maximum price level")
    func testFilterByMaximumPrice() async throws {
        // Arrange
        let pois = createSamplePOIs()
        let filter = POIFilter(maximumPriceLevel: 1)

        // Act
        let results = service.filter(pois, using: filter, sortedBy: .name)

        // Assert
        #expect(results.allSatisfy { poi in
            guard let rating = poi.rating, let price = rating.priceLevel else { return true }
            return price <= 1
        })
    }

    @Test("Filters POIs by tags")
    func testFilterByTags() async throws {
        // Arrange
        let pois = createSamplePOIs()
        let filter = POIFilter(tags: ["scenic"])

        // Act
        let results = service.filter(pois, using: filter, sortedBy: .name)

        // Assert
        #expect(results.count == 1)
        #expect(results[0].name == "Multnomah Falls")
    }

    @Test("Filters POIs by source")
    func testFilterBySource() async throws {
        // Arrange
        let pois = createSamplePOIs()
        let filter = POIFilter(sources: [.google])

        // Act
        let results = service.filter(pois, using: filter, sortedBy: .name)

        // Assert
        #expect(results.allSatisfy { $0.source == .google })
    }

    @Test("Combines multiple filter criteria")
    func testCombinedFilters() async throws {
        // Arrange
        let pois = createSamplePOIs()
        let filter = POIFilter(
            location: portland,
            radiusMiles: 10.0,
            minimumRating: 4.5,
            maximumPriceLevel: 2
        )

        // Act
        let results = service.filter(pois, using: filter, sortedBy: .rating)

        // Assert
        #expect(results.allSatisfy { poi in
            guard let rating = poi.rating else { return false }
            return rating.averageRating >= 4.5
        })
        #expect(!results.contains(where: { $0.name == "Pike Place Market" })) // Too far
    }

    @Test("Sorts POIs by distance")
    func testSortByDistance() async throws {
        // Arrange
        let pois = createSamplePOIs()
        let filter = POIFilter(
            location: portland,
            radiusMiles: 50.0
        )

        // Act
        let results = service.filter(pois, using: filter, sortedBy: .distance)

        // Assert
        #expect(results.count >= 3)
        // First result should be closest to Portland
        if results.count >= 2 {
            let distance1 = results[0].location.distance(to: portland)
            let distance2 = results[1].location.distance(to: portland)
            #expect(distance1 <= distance2)
        }
    }

    @Test("Sorts POIs by rating")
    func testSortByRating() async throws {
        // Arrange
        let pois = createSamplePOIs()
        let filter = POIFilter(minimumRating: 4.0)

        // Act
        let results = service.filter(pois, using: filter, sortedBy: .rating)

        // Assert
        if results.count >= 2 {
            let rating1 = results[0].rating?.averageRating ?? 0
            let rating2 = results[1].rating?.averageRating ?? 0
            #expect(rating1 >= rating2)
        }
    }

    @Test("Sorts POIs by name")
    func testSortByName() async throws {
        // Arrange
        let pois = createSamplePOIs()
        let filter = POIFilter()

        // Act
        let results = service.filter(pois, using: filter, sortedBy: .name)

        // Assert
        if results.count >= 2 {
            #expect(results[0].name <= results[1].name)
        }
    }

    @Test("Creates filter for user personalization")
    func testUserPersonalizedFilter() async throws {
        // Arrange
        let user = User(
            email: "test@example.com",
            displayName: "Test User",
            interests: [
                UserInterest(name: "Nature", category: .nature),
                UserInterest(name: "Food", category: .food)
            ]
        )

        // Act
        let filter = POIFilter.forUser(user, near: portland, radiusMiles: 10.0)

        // Assert
        #expect(filter.interests?.count == 2)
        #expect(filter.location != nil)
        #expect(filter.radiusMiles == 10.0)
    }

    @Test("Creates filter for EV chargers")
    func testEVChargerFilter() async throws {
        // Arrange
        let pois = createSamplePOIs()

        // Act
        let filter = POIFilter.evChargers(near: portland, radiusMiles: 10.0)
        let results = service.filter(pois, using: filter, sortedBy: .distance)

        // Assert
        #expect(results.count == 1)
        #expect(results[0].category == .evCharger)
    }
}

@Suite("POI Repository", .tags(.medium))
struct POIRepositoryTests {

    @Test("In-memory repository stores and retrieves POIs")
    func testSaveAndRetrieve() async throws {
        // Arrange
        let repository = InMemoryPOIRepository()
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let poi = POI(
            name: "Test POI",
            category: .restaurant,
            location: location
        )

        // Act
        let saved = try await repository.save(poi)
        let retrieved = try await repository.find(id: saved.id)

        // Assert
        #expect(retrieved != nil)
        #expect(retrieved?.name == "Test POI")
    }

    @Test("Repository finds all POIs")
    func testFindAll() async throws {
        // Arrange
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let poi1 = POI(name: "POI 1", category: .restaurant, location: location)
        let poi2 = POI(name: "POI 2", category: .park, location: location)
        let repository = InMemoryPOIRepository(initialPOIs: [poi1, poi2])

        // Act
        let allPOIs = try await repository.findAll()

        // Assert
        #expect(allPOIs.count == 2)
    }

    @Test("Repository deletes POIs")
    func testDelete() async throws {
        // Arrange
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let poi = POI(name: "Test POI", category: .restaurant, location: location)
        let repository = InMemoryPOIRepository(initialPOIs: [poi])

        // Act
        try await repository.delete(id: poi.id)
        let retrieved = try await repository.find(id: poi.id)

        // Assert
        #expect(retrieved == nil)
    }

    @Test("Repository finds POIs matching filter")
    func testFindWithFilter() async throws {
        // Arrange
        let portland = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let poi1 = POI(
            name: "Portland Restaurant",
            category: .restaurant,
            location: portland,
            rating: POIRating(averageRating: 4.5, totalRatings: 100)
        )
        let poi2 = POI(
            name: "Portland Park",
            category: .park,
            location: portland,
            rating: POIRating(averageRating: 3.5, totalRatings: 50)
        )
        let repository = InMemoryPOIRepository(initialPOIs: [poi1, poi2])
        let filter = POIFilter(minimumRating: 4.0)

        // Act
        let results = try await repository.find(matching: filter)

        // Assert
        #expect(results.count == 1)
        #expect(results[0].name == "Portland Restaurant")
    }

    @Test("Repository finds nearby POIs")
    func testFindNearby() async throws {
        // Arrange
        let portland = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let nearby = GeoLocation(latitude: 45.5200, longitude: -122.6800)
        let farAway = GeoLocation(latitude: 47.6062, longitude: -122.3321) // Seattle

        let poi1 = POI(name: "Nearby POI", category: .restaurant, location: nearby)
        let poi2 = POI(name: "Far Away POI", category: .restaurant, location: farAway)
        let repository = InMemoryPOIRepository(initialPOIs: [poi1, poi2])

        // Act
        let results = try await repository.findNearby(
            location: portland,
            radiusMiles: 5.0,
            categories: nil
        )

        // Assert
        #expect(results.count == 1)
        #expect(results[0].name == "Nearby POI")
    }

    @Test("Repository finds nearby POIs filtered by category")
    func testFindNearbyByCategory() async throws {
        // Arrange
        let portland = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let nearby1 = GeoLocation(latitude: 45.5200, longitude: -122.6800)
        let nearby2 = GeoLocation(latitude: 45.5180, longitude: -122.6750)

        let poi1 = POI(name: "Nearby Restaurant", category: .restaurant, location: nearby1)
        let poi2 = POI(name: "Nearby Park", category: .park, location: nearby2)
        let repository = InMemoryPOIRepository(initialPOIs: [poi1, poi2])

        // Act
        let results = try await repository.findNearby(
            location: portland,
            radiusMiles: 5.0,
            categories: [.restaurant]
        )

        // Assert
        #expect(results.count == 1)
        #expect(results[0].name == "Nearby Restaurant")
    }
}
