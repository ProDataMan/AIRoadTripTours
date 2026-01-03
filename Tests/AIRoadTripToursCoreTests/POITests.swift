import Testing
import Foundation
@testable import AIRoadTripToursCore

@Suite("Point of Interest - Basic Functionality", .tags(.small))
struct POITests {

    @Test("Creates POI with required fields")
    func testPOICreation() async throws {
        // Arrange & Act
        let location = GeoLocation(
            latitude: 45.5152,
            longitude: -122.6784,
            address: "Portland, OR"
        )
        let poi = POI(
            name: "Multnomah Falls",
            description: "Beautiful waterfall in the Columbia River Gorge",
            category: .waterfall,
            location: location
        )

        // Assert
        #expect(poi.name == "Multnomah Falls")
        #expect(poi.category == .waterfall)
        #expect(poi.location.latitude == 45.5152)
        #expect(poi.description != nil)
    }

    @Test("POI includes contact information")
    func testPOIWithContact() async throws {
        // Arrange
        let contact = POIContact(
            phone: "+1-503-555-0100",
            website: "https://example.com",
            email: "info@example.com"
        )
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)

        // Act
        let poi = POI(
            name: "Test Restaurant",
            category: .restaurant,
            location: location,
            contact: contact
        )

        // Assert
        #expect(poi.contact?.phone == "+1-503-555-0100")
        #expect(poi.contact?.website == "https://example.com")
    }

    @Test("POI includes rating information")
    func testPOIWithRating() async throws {
        // Arrange
        let rating = POIRating(averageRating: 4.5, totalRatings: 128, priceLevel: 2)
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)

        // Act
        let poi = POI(
            name: "Popular Cafe",
            category: .cafe,
            location: location,
            rating: rating
        )

        // Assert
        #expect(poi.rating?.averageRating == 4.5)
        #expect(poi.rating?.totalRatings == 128)
        #expect(poi.rating?.priceLevel == 2)
    }

    @Test("POI includes operating hours")
    func testPOIWithHours() async throws {
        // Arrange
        let hours = POIHours(description: "Mon-Fri 9am-5pm", isOpenNow: true)
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)

        // Act
        let poi = POI(
            name: "Museum",
            category: .museum,
            location: location,
            hours: hours
        )

        // Assert
        #expect(poi.hours?.description == "Mon-Fri 9am-5pm")
        #expect(poi.hours?.isOpenNow == true)
    }

    @Test("POI supports tags for additional categorization")
    func testPOIWithTags() async throws {
        // Arrange
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let tags: Set<String> = ["family-friendly", "wheelchair-accessible", "pet-friendly"]

        // Act
        let poi = POI(
            name: "City Park",
            category: .park,
            location: location,
            tags: tags
        )

        // Assert
        #expect(poi.tags.count == 3)
        #expect(poi.tags.contains("family-friendly"))
        #expect(poi.tags.contains("wheelchair-accessible"))
    }

    @Test("POI tracks data source")
    func testPOISource() async throws {
        // Arrange
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)

        // Act
        let googlePOI = POI(
            name: "Google Place",
            category: .restaurant,
            location: location,
            source: .google
        )
        let userPOI = POI(
            name: "User Suggested",
            category: .scenic,
            location: location,
            source: .userSubmitted
        )

        // Assert
        #expect(googlePOI.source == .google)
        #expect(userPOI.source == .userSubmitted)
    }
}

@Suite("POI Category to Interest Mapping", .tags(.small))
struct POICategoryMappingTests {

    @Test("Restaurant category maps to food interest")
    func testRestaurantMapping() async throws {
        #expect(POICategory.restaurant.relatedInterests.contains(.food))
    }

    @Test("Hiking category maps to nature and adventure interests")
    func testHikingMapping() async throws {
        let interests = POICategory.hiking.relatedInterests
        #expect(interests.contains(.nature))
        #expect(interests.contains(.adventure))
    }

    @Test("Museum category maps to culture and history interests")
    func testMuseumMapping() async throws {
        let interests = POICategory.museum.relatedInterests
        #expect(interests.contains(.culture))
        #expect(interests.contains(.history))
    }

    @Test("Scenic category maps to scenic and nature interests")
    func testScenicMapping() async throws {
        let interests = POICategory.scenic.relatedInterests
        #expect(interests.contains(.scenic))
        #expect(interests.contains(.nature))
    }

    @Test("EV charger has no related interests")
    func testEVChargerMapping() async throws {
        #expect(POICategory.evCharger.relatedInterests.isEmpty)
    }
}

@Suite("POI Interest Matching", .tags(.small))
struct POIInterestMatchingTests {

    @Test("POI matches user with relevant interests")
    func testMatchingInterests() async throws {
        // Arrange
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let poi = POI(
            name: "Hiking Trail",
            category: .hiking,
            location: location
        )
        let userInterests: Set<UserInterest> = [
            UserInterest(name: "Hiking", category: .adventure),
            UserInterest(name: "Scenic Views", category: .scenic)
        ]

        // Act
        let matches = poi.matches(interests: userInterests)

        // Assert
        #expect(matches)
    }

    @Test("POI does not match user with unrelated interests")
    func testNonMatchingInterests() async throws {
        // Arrange
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let poi = POI(
            name: "Shopping Mall",
            category: .shopping,
            location: location
        )
        let userInterests: Set<UserInterest> = [
            UserInterest(name: "Hiking", category: .adventure),
            UserInterest(name: "Museums", category: .culture)
        ]

        // Act
        let matches = poi.matches(interests: userInterests)

        // Assert
        #expect(!matches)
    }

    @Test("POI matches if any interest overlaps")
    func testPartialInterestMatch() async throws {
        // Arrange
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let poi = POI(
            name: "National Park",
            category: .park,
            location: location
        )
        let userInterests: Set<UserInterest> = [
            UserInterest(name: "Shopping", category: .shopping),
            UserInterest(name: "Nature", category: .nature)  // This matches!
        ]

        // Act
        let matches = poi.matches(interests: userInterests)

        // Assert
        #expect(matches)
    }
}

@Suite("Geographic Location", .tags(.small))
struct GeoLocationTests {

    @Test("Calculates distance between two locations")
    func testDistanceCalculation() async throws {
        // Arrange - Portland and Seattle (roughly 173 miles apart)
        let portland = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let seattle = GeoLocation(latitude: 47.6062, longitude: -122.3321)

        // Act
        let distance = portland.distance(to: seattle)

        // Assert - allow some tolerance in calculation
        #expect(distance > 140)
        #expect(distance < 200)
    }

    @Test("Distance to same location is zero")
    func testZeroDistance() async throws {
        // Arrange
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)

        // Act
        let distance = location.distance(to: location)

        // Assert
        #expect(distance < 0.01) // Essentially zero
    }

    @Test("POI checks if within distance radius")
    func testWithinRadius() async throws {
        // Arrange
        let poiLocation = GeoLocation(latitude: 45.5152, longitude: -122.6784)
        let poi = POI(
            name: "Portland Attraction",
            category: .attraction,
            location: poiLocation
        )
        let userLocation = GeoLocation(latitude: 45.5230, longitude: -122.6765) // ~0.5 miles away

        // Act
        let isNearby = poi.isWithin(miles: 1.0, of: userLocation)
        let isFarAway = poi.isWithin(miles: 0.1, of: userLocation)

        // Assert
        #expect(isNearby)
        #expect(!isFarAway)
    }

    @Test("Converts to CoreLocation coordinate")
    func testCoordinateConversion() async throws {
        // Arrange
        let location = GeoLocation(latitude: 45.5152, longitude: -122.6784)

        // Act
        let coordinate = location.coordinate

        // Assert
        #expect(coordinate.latitude == 45.5152)
        #expect(coordinate.longitude == -122.6784)
    }
}
