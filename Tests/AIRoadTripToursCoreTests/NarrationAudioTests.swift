import Testing
import Foundation
@testable import AIRoadTripToursCore

@Suite("Narration Audio Service", .tags(.medium))
struct NarrationAudioServiceTests {
    let audioService = MockNarrationAudioService()

    @Test("Prepares narration audio")
    func testPrepareAudio() async throws {
        // Arrange
        let narration = Narration(
            poiId: UUID(),
            poiName: "Test POI",
            title: "About Test POI",
            content: "This is a test narration with some content.",
            durationSeconds: 60.0
        )

        // Act
        try await audioService.prepare(narration)

        // Assert
        let state = await audioService.playbackState
        #expect(state == .idle)
        #expect(await audioService.prepareCallCount == 1)
    }

    @Test("Plays narration audio")
    func testPlayAudio() async throws {
        // Arrange
        let narration = Narration(
            poiId: UUID(),
            poiName: "Test POI",
            title: "Test",
            content: "Test content for narration.",
            durationSeconds: 30.0
        )

        // Act
        try await audioService.play(narration)

        // Assert
        let state = await audioService.playbackState
        #expect(state == .completed)
        #expect(await audioService.playCallCount == 1)
    }

    @Test("Pauses playback")
    func testPausePlayback() async throws {
        // Arrange
        let narration = Narration(
            poiId: UUID(),
            poiName: "Test",
            title: "Test",
            content: "Test content.",
            durationSeconds: 60.0
        )
        await audioService.setState(.playing)

        // Act
        await audioService.pause()

        // Assert
        let state = await audioService.playbackState
        #expect(state == .paused)
        #expect(await audioService.pauseCallCount == 1)
    }

    @Test("Resumes paused playback")
    func testResumePlayback() async throws {
        // Arrange
        await audioService.setState(.paused)

        // Act
        await audioService.resume()

        // Assert
        let state = await audioService.playbackState
        #expect(state == .playing)
        #expect(await audioService.resumeCallCount == 1)
    }

    @Test("Stops playback")
    func testStopPlayback() async throws {
        // Arrange
        let narration = Narration(
            poiId: UUID(),
            poiName: "Test",
            title: "Test",
            content: "Test content.",
            durationSeconds: 60.0
        )
        await audioService.setState(.playing)
        await audioService.setNarration(narration)

        // Act
        await audioService.stop()

        // Assert
        let state = await audioService.playbackState
        #expect(state == .idle)
        #expect(await audioService.currentNarration == nil)
        #expect(await audioService.stopCallCount == 1)
    }

    @Test("Tracks current narration")
    func testTrackCurrentNarration() async throws {
        // Arrange
        let narration = Narration(
            poiId: UUID(),
            poiName: "Multnomah Falls",
            title: "About Multnomah Falls",
            content: "Beautiful waterfall narration.",
            durationSeconds: 120.0
        )

        // Act
        try await audioService.prepare(narration)

        // Assert
        let current = await audioService.currentNarration
        #expect(current?.id == narration.id)
        #expect(current?.poiName == "Multnomah Falls")
    }
}

@Suite("Narration Playback States", .tags(.small))
struct NarrationPlaybackStateTests {
    @Test("Playback state transitions")
    func testStateTransitions() async throws {
        // Arrange
        let service = MockNarrationAudioService()
        let narration = Narration(
            poiId: UUID(),
            poiName: "Test",
            title: "Test",
            content: "Test",
            durationSeconds: 30.0
        )

        // Act & Assert - Initial state
        #expect(await service.playbackState == .idle)

        // Prepare
        try await service.prepare(narration)
        #expect(await service.playbackState == .idle)

        // Play
        await service.setState(.playing)
        #expect(await service.playbackState == .playing)

        // Pause
        await service.pause()
        #expect(await service.playbackState == .paused)

        // Resume
        await service.resume()
        #expect(await service.playbackState == .playing)

        // Stop
        await service.stop()
        #expect(await service.playbackState == .idle)
    }
}

@Suite("Narration Audio Integration with Queue", .tags(.medium))
struct NarrationAudioQueueIntegrationTests {
    @Test("Plays narrations from queue sequentially")
    func testQueuePlayback() async throws {
        // Arrange
        let queue = NarrationQueue()
        let audioService = MockNarrationAudioService()

        let narrations = [
            Narration(poiId: UUID(), poiName: "POI 1", title: "T1", content: "Content 1", durationSeconds: 30.0),
            Narration(poiId: UUID(), poiName: "POI 2", title: "T2", content: "Content 2", durationSeconds: 30.0),
            Narration(poiId: UUID(), poiName: "POI 3", title: "T3", content: "Content 3", durationSeconds: 30.0)
        ]

        await queue.enqueue(narrations)

        // Act - Play each narration from queue
        var playedCount = 0
        while let narration = await queue.next() {
            await queue.updateStatus(narration.id, status: .playing)
            try await audioService.play(narration)
            await queue.updateStatus(narration.id, status: .completed)
            playedCount += 1
        }

        // Assert
        #expect(playedCount == 3)
        #expect(await audioService.playCallCount == 3)
        #expect(await queue.pendingCount() == 0)
    }

    @Test("Can pause and resume queue playback")
    func testQueuePauseResume() async throws {
        // Arrange
        let queue = NarrationQueue()
        let audioService = MockNarrationAudioService()

        let narration = Narration(
            poiId: UUID(),
            poiName: "Test",
            title: "Test",
            content: "Test content",
            durationSeconds: 60.0
        )

        await queue.enqueue([narration])
        guard let current = await queue.next() else {
            throw NarrationError.noContentAvailable
        }

        // Act
        await queue.updateStatus(current.id, status: .playing)
        await audioService.setState(.playing)

        await audioService.pause()
        #expect(await audioService.playbackState == .paused)

        await audioService.resume()
        #expect(await audioService.playbackState == .playing)

        await audioService.stop()
        await queue.updateStatus(current.id, status: .completed)

        // Assert
        #expect(await queue.pendingCount() == 0)
    }

    @Test("Can skip narrations in queue")
    func testSkipNarration() async throws {
        // Arrange
        let queue = NarrationQueue()
        let audioService = MockNarrationAudioService()

        let narrations = [
            Narration(poiId: UUID(), poiName: "POI 1", title: "T1", content: "C1", durationSeconds: 30.0),
            Narration(poiId: UUID(), poiName: "POI 2", title: "T2", content: "C2", durationSeconds: 30.0)
        ]

        await queue.enqueue(narrations)

        // Act - Play first, skip second
        if let first = await queue.next() {
            try await audioService.play(first)
            await queue.updateStatus(first.id, status: .completed)
        }

        if let second = await queue.next() {
            await audioService.stop()
            await queue.updateStatus(second.id, status: .skipped)
        }

        // Assert
        let all = await queue.all()
        let completed = all.filter { $0.status == .completed }
        let skipped = all.filter { $0.status == .skipped }

        #expect(completed.count == 1)
        #expect(skipped.count == 1)
    }
}

@Suite("Narration Audio Error Handling", .tags(.small))
struct NarrationAudioErrorTests {
    @Test("Audio error descriptions are meaningful")
    func testErrorDescriptions() {
        // Arrange & Act
        let synthesisError = NarrationAudioError.synthesisFailure("Voice not available")
        let playbackError = NarrationAudioError.playbackFailure("Audio interrupted")
        let sessionError = NarrationAudioError.audioSessionFailure("Session deactivated")
        let noPreparedError = NarrationAudioError.noAudioPrepared

        // Assert
        #expect(synthesisError.errorDescription?.contains("synthesis") == true)
        #expect(playbackError.errorDescription?.contains("playback") == true)
        #expect(sessionError.errorDescription?.contains("session") == true)
        #expect(noPreparedError.errorDescription?.contains("No audio") == true)
    }
}
