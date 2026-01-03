import Testing
import Foundation
@testable import AIRoadTripToursCore

@Suite("Narration Model", .tags(.small))
struct NarrationModelTests {

    @Test("Creates narration with required fields")
    func testNarrationCreation() async throws {
        // Arrange & Act
        let poiId = UUID()
        let narration = Narration(
            poiId: poiId,
            poiName: "Multnomah Falls",
            title: "About Multnomah Falls",
            content: "This is a beautiful waterfall...",
            durationSeconds: 180.0
        )

        // Assert
        #expect(narration.poiId == poiId)
        #expect(narration.poiName == "Multnomah Falls")
        #expect(narration.status == .queued)
        #expect(narration.durationSeconds == 180.0)
        #expect(narration.startedAt == nil)
        #expect(narration.completedAt == nil)
    }

    @Test("Calculates word count from content")
    func testWordCount() async throws {
        // Arrange
        let content = "This is a test narration with exactly ten words here."
        let narration = Narration(
            poiId: UUID(),
            poiName: "Test",
            title: "Test",
            content: content,
            durationSeconds: 60.0
        )

        // Act
        let wordCount = narration.wordCount

        // Assert
        #expect(wordCount == 10)
    }

    @Test("Tracks narration status changes")
    func testStatusTracking() async throws {
        // Arrange
        var narration = Narration(
            poiId: UUID(),
            poiName: "Test",
            title: "Test",
            content: "Test content",
            durationSeconds: 60.0
        )

        // Act & Assert - Initial status
        #expect(narration.status == .queued)

        // Update to playing
        narration.status = .playing
        narration.startedAt = Date()
        #expect(narration.status == .playing)
        #expect(narration.startedAt != nil)

        // Update to completed
        narration.status = .completed
        narration.completedAt = Date()
        #expect(narration.status == .completed)
        #expect(narration.completedAt != nil)
    }
}

@Suite("Narration Timing Calculator", .tags(.small))
struct NarrationTimingTests {
    let calculator = StandardNarrationTimingCalculator()

    // Helper to create test narration
    func createTestNarration(durationSeconds: Double) -> Narration {
        Narration(
            poiId: UUID(),
            poiName: "Test POI",
            title: "Test",
            content: String(repeating: "word ", count: Int((durationSeconds / 60.0) * 150)),
            durationSeconds: durationSeconds
        )
    }

    @Test("Calculates timing for 3-minute narration at 30 mph")
    func testTimingAt30Mph() async throws {
        // Arrange
        let narration = createTestNarration(durationSeconds: 180.0) // 3 minutes
        let distanceFromPOI = 5.0 // 5 miles away
        let speed = 30.0 // 30 mph

        // Act
        let timing = calculator.calculateTiming(
            for: narration,
            distanceFromPOIMiles: distanceFromPOI,
            currentSpeedMph: speed,
            targetArrivalWindowSeconds: 60...120
        )

        // Assert
        // At 30 mph, in 3 minutes we travel 1.5 miles
        #expect(timing.narrationTravelDistanceMiles > 1.4)
        #expect(timing.narrationTravelDistanceMiles < 1.6)

        // Should trigger before traveling the full distance
        #expect(timing.triggerDistanceMiles < distanceFromPOI)
        #expect(timing.triggerDistanceMiles > 0)

        // Should be valid timing
        #expect(timing.isValid)

        // Should complete before reaching POI
        #expect(timing.distanceFromPOIOnCompletionMiles > 0)
    }

    @Test("Calculates timing for 2-minute narration at 60 mph")
    func testTimingAt60Mph() async throws {
        // Arrange
        let narration = createTestNarration(durationSeconds: 120.0) // 2 minutes
        let distanceFromPOI = 5.0 // 5 miles away
        let speed = 60.0 // 60 mph

        // Act
        let timing = calculator.calculateTiming(
            for: narration,
            distanceFromPOIMiles: distanceFromPOI,
            currentSpeedMph: speed,
            targetArrivalWindowSeconds: 60...120
        )

        // Assert
        // At 60 mph, in 2 minutes we travel 2 miles
        #expect(timing.narrationTravelDistanceMiles > 1.9)
        #expect(timing.narrationTravelDistanceMiles < 2.1)

        #expect(timing.isValid)
        #expect(timing.distanceFromPOIOnCompletionMiles > 0)
    }

    @Test("Detects invalid timing when too close to POI")
    func testInvalidTimingTooClose() async throws {
        // Arrange
        let narration = createTestNarration(durationSeconds: 180.0) // 3 minutes
        let distanceFromPOI = 0.5 // Only 0.5 miles away
        let speed = 30.0 // 30 mph

        // Act
        let timing = calculator.calculateTiming(
            for: narration,
            distanceFromPOIMiles: distanceFromPOI,
            currentSpeedMph: speed,
            targetArrivalWindowSeconds: 60...120
        )

        // Assert - may not be valid if we'd pass POI before narration ends
        // At 30 mph for 3 min = 1.5 miles, but only 0.5 miles away
        #expect(!timing.isValid)
    }

    @Test("Adjusts timing for slow speed")
    func testSlowSpeedTiming() async throws {
        // Arrange
        let narration = createTestNarration(durationSeconds: 60.0) // 1 minute
        let distanceFromPOI = 2.0
        let speed = 15.0 // Slow speed - 15 mph

        // Act
        let timing = calculator.calculateTiming(
            for: narration,
            distanceFromPOIMiles: distanceFromPOI,
            currentSpeedMph: speed,
            targetArrivalWindowSeconds: 60...120
        )

        // Assert
        // At 15 mph, in 1 minute we travel 0.25 miles
        #expect(timing.narrationTravelDistanceMiles > 0.2)
        #expect(timing.narrationTravelDistanceMiles < 0.3)

        #expect(timing.isValid)
    }

    @Test("Calculates time to trigger correctly")
    func testTimeToTrigger() async throws {
        // Arrange
        let narration = createTestNarration(durationSeconds: 120.0) // 2 minutes
        let distanceFromPOI = 3.0 // 3 miles
        let speed = 30.0 // 30 mph

        // Act
        let timing = calculator.calculateTiming(
            for: narration,
            distanceFromPOIMiles: distanceFromPOI,
            currentSpeedMph: speed,
            targetArrivalWindowSeconds: 60...120
        )

        // Assert
        // Time to trigger should be positive
        #expect(timing.timeToTriggerSeconds >= 0)

        // At 30 mph, should take specific time to reach trigger point
        let expectedTimeMinutes = (distanceFromPOI - timing.triggerDistanceMiles) / speed * 60.0
        #expect(abs(timing.timeToTriggerSeconds - expectedTimeMinutes * 60) < 1.0)
    }

    @Test("Respects minimum trigger distance")
    func testMinimumTriggerDistance() async throws {
        // Arrange
        let narration = createTestNarration(durationSeconds: 30.0) // Very short - 30 seconds
        let distanceFromPOI = 0.8 // Close
        let speed = 60.0 // Fast

        // Act
        let timing = calculator.calculateTiming(
            for: narration,
            distanceFromPOIMiles: distanceFromPOI,
            currentSpeedMph: speed,
            targetArrivalWindowSeconds: 60...120
        )

        // Assert
        // Should use minimum trigger distance (0.5 miles default)
        #expect(timing.triggerDistanceMiles >= 0.5)
    }

    @Test("Handles zero distance correctly")
    func testZeroDistance() async throws {
        // Arrange
        let narration = createTestNarration(durationSeconds: 60.0)
        let distanceFromPOI = 0.0 // Already at POI
        let speed = 30.0

        // Act
        let timing = calculator.calculateTiming(
            for: narration,
            distanceFromPOIMiles: distanceFromPOI,
            currentSpeedMph: speed,
            targetArrivalWindowSeconds: 60...120
        )

        // Assert
        #expect(!timing.isValid)
        #expect(timing.timeToTriggerSeconds == 0)
    }
}

@Suite("AI Content Generation", .tags(.medium))
struct AIContentGenerationTests {
    let generator = MockContentGenerator()

    @Test("Generates narration for waterfall POI")
    func testWaterfallNarration() async throws {
        // Arrange
        let poi = POI(
            name: "Multnomah Falls",
            description: "A 620-foot waterfall",
            category: .waterfall,
            location: GeoLocation(latitude: 45.5762, longitude: -122.1153)
        )
        let interests: Set<UserInterest> = [
            UserInterest(name: "Nature", category: .nature)
        ]

        // Act
        let narration = try await generator.generateNarration(
            for: poi,
            targetDurationSeconds: 180.0,
            userInterests: interests
        )

        // Assert
        #expect(narration.poiId == poi.id)
        #expect(narration.poiName == poi.name)
        #expect(narration.content.contains(poi.name))
        #expect(!narration.content.isEmpty)
        #expect(narration.durationSeconds > 0)
        #expect(narration.wordCount > 0)
    }

    @Test("Generates narration for restaurant POI")
    func testRestaurantNarration() async throws {
        // Arrange
        let poi = POI(
            name: "Voodoo Doughnut",
            description: "Famous doughnut shop",
            category: .restaurant,
            location: GeoLocation(latitude: 45.5228, longitude: -122.6731),
            rating: POIRating(averageRating: 4.2, totalRatings: 10000, priceLevel: 1)
        )
        let interests: Set<UserInterest> = [
            UserInterest(name: "Food", category: .food)
        ]

        // Act
        let narration = try await generator.generateNarration(
            for: poi,
            targetDurationSeconds: 120.0,
            userInterests: interests
        )

        // Assert
        #expect(narration.content.contains(poi.name))
        #expect(narration.content.contains("4.1") || narration.content.contains("4.2")) // Rating mentioned
    }

    @Test("Generates narration for park POI")
    func testParkNarration() async throws {
        // Arrange
        let poi = POI(
            name: "Portland Japanese Garden",
            description: "Traditional Japanese garden",
            category: .park,
            location: GeoLocation(latitude: 45.5195, longitude: -122.7057)
        )
        let interests: Set<UserInterest> = []

        // Act
        let narration = try await generator.generateNarration(
            for: poi,
            targetDurationSeconds: 90.0,
            userInterests: interests
        )

        // Assert
        #expect(narration.content.contains(poi.name))
        #expect(!narration.content.isEmpty)
    }

    @Test("Narration duration matches content length")
    func testDurationMatchesContent() async throws {
        // Arrange
        let poi = POI(
            name: "Test POI",
            category: .attraction,
            location: GeoLocation(latitude: 45.5, longitude: -122.6)
        )

        // Act
        let narration = try await generator.generateNarration(
            for: poi,
            targetDurationSeconds: 180.0,
            userInterests: []
        )

        // Assert
        // At 150 words per minute, 3 minutes = 450 words
        // Duration should be roughly based on word count
        let expectedDuration = (Double(narration.wordCount) / 150.0) * 60.0
        #expect(abs(narration.durationSeconds - expectedDuration) < 30) // Within 30 seconds
    }
}

@Suite("Narration Queue Management", .tags(.medium))
struct NarrationQueueTests {

    @Test("Enqueues multiple narrations")
    func testEnqueueNarrations() async throws {
        // Arrange
        let queue = NarrationQueue()
        let narrations = [
            Narration(
                poiId: UUID(),
                poiName: "POI 1",
                title: "About POI 1",
                content: "Content 1",
                durationSeconds: 60.0
            ),
            Narration(
                poiId: UUID(),
                poiName: "POI 2",
                title: "About POI 2",
                content: "Content 2",
                durationSeconds: 90.0
            )
        ]

        // Act
        await queue.enqueue(narrations)
        let all = await queue.all()

        // Assert
        #expect(all.count == 2)
    }

    @Test("Returns next queued narration")
    func testNextNarration() async throws {
        // Arrange
        let queue = NarrationQueue()
        let narration1 = Narration(
            poiId: UUID(),
            poiName: "POI 1",
            title: "Title 1",
            content: "Content 1",
            durationSeconds: 60.0
        )
        let narration2 = Narration(
            poiId: UUID(),
            poiName: "POI 2",
            title: "Title 2",
            content: "Content 2",
            durationSeconds: 90.0
        )

        await queue.enqueue([narration1, narration2])

        // Act
        let next = await queue.next()

        // Assert
        #expect(next != nil)
        #expect(next?.id == narration1.id)
    }

    @Test("Updates narration status")
    func testUpdateStatus() async throws {
        // Arrange
        let queue = NarrationQueue()
        let narration = Narration(
            poiId: UUID(),
            poiName: "Test",
            title: "Test",
            content: "Test",
            durationSeconds: 60.0
        )
        await queue.enqueue([narration])

        // Act
        await queue.updateStatus(narration.id, status: .playing)
        let all = await queue.all()

        // Assert
        let updated = all.first { $0.id == narration.id }
        #expect(updated?.status == .playing)
        #expect(updated?.startedAt != nil)
    }

    @Test("Tracks completion status")
    func testCompletionTracking() async throws {
        // Arrange
        let queue = NarrationQueue()
        let narration = Narration(
            poiId: UUID(),
            poiName: "Test",
            title: "Test",
            content: "Test",
            durationSeconds: 60.0
        )
        await queue.enqueue([narration])

        // Act
        await queue.updateStatus(narration.id, status: .completed)
        let all = await queue.all()

        // Assert
        let completed = all.first { $0.id == narration.id }
        #expect(completed?.status == .completed)
        #expect(completed?.completedAt != nil)
    }

    @Test("Returns nil when queue is empty")
    func testEmptyQueue() async throws {
        // Arrange
        let queue = NarrationQueue()

        // Act
        let next = await queue.next()

        // Assert
        #expect(next == nil)
    }

    @Test("Clears all narrations")
    func testClearQueue() async throws {
        // Arrange
        let queue = NarrationQueue()
        let narrations = [
            Narration(
                poiId: UUID(),
                poiName: "POI 1",
                title: "Title 1",
                content: "Content 1",
                durationSeconds: 60.0
            )
        ]
        await queue.enqueue(narrations)

        // Act
        await queue.clear()
        let all = await queue.all()

        // Assert
        #expect(all.isEmpty)
    }

    @Test("Counts pending narrations")
    func testPendingCount() async throws {
        // Arrange
        let queue = NarrationQueue()
        let narrations = [
            Narration(poiId: UUID(), poiName: "POI 1", title: "T1", content: "C1", durationSeconds: 60.0),
            Narration(poiId: UUID(), poiName: "POI 2", title: "T2", content: "C2", durationSeconds: 60.0, status: .completed),
            Narration(poiId: UUID(), poiName: "POI 3", title: "T3", content: "C3", durationSeconds: 60.0)
        ]
        await queue.enqueue(narrations)

        // Act
        let count = await queue.pendingCount()

        // Assert
        #expect(count == 2) // Two queued, one completed
    }

    @Test("Gets current playing narration")
    func testCurrentNarration() async throws {
        // Arrange
        let queue = NarrationQueue()
        let narration = Narration(
            poiId: UUID(),
            poiName: "Test",
            title: "Test",
            content: "Test",
            durationSeconds: 60.0
        )
        await queue.enqueue([narration])

        // Act
        let _ = await queue.next() // This sets current
        let current = await queue.current()

        // Assert
        #expect(current != nil)
        #expect(current?.id == narration.id)
    }
}
