import Foundation

/// Status of a narration.
public enum NarrationStatus: String, Codable, Sendable {
    case queued = "Queued"
    case scheduled = "Scheduled"
    case playing = "Playing"
    case completed = "Completed"
    case skipped = "Skipped"
    case cancelled = "Cancelled"
}

/// Represents a narration/story about a POI.
public struct Narration: Identifiable, Codable, Sendable {
    /// Unique identifier.
    public let id: UUID

    /// Associated POI.
    public let poiId: UUID

    /// POI name for reference.
    public let poiName: String

    /// Narration title.
    public let title: String

    /// Story content (text).
    public let content: String

    /// Estimated reading/speaking duration in seconds.
    public let durationSeconds: Double

    /// When this narration was generated.
    public let generatedAt: Date

    /// Current status.
    public var status: NarrationStatus

    /// When narration started playing.
    public var startedAt: Date?

    /// When narration completed.
    public var completedAt: Date?

    /// Source of the narration content.
    public let source: String

    public init(
        id: UUID = UUID(),
        poiId: UUID,
        poiName: String,
        title: String,
        content: String,
        durationSeconds: Double,
        generatedAt: Date = Date(),
        status: NarrationStatus = .queued,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        source: String = "AI Generated"
    ) {
        self.id = id
        self.poiId = poiId
        self.poiName = poiName
        self.title = title
        self.content = content
        self.durationSeconds = durationSeconds
        self.generatedAt = generatedAt
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.source = source
    }

    /// Estimated word count based on content.
    public var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}

/// Timing information for when to trigger a narration.
public struct NarrationTiming: Codable, Sendable {
    /// Distance from POI when narration should start (in miles).
    public let triggerDistanceMiles: Double

    /// Current vehicle speed in mph.
    public let currentSpeedMph: Double

    /// Time until narration should start (in seconds).
    public let timeToTriggerSeconds: Double

    /// Distance user will travel during narration (in miles).
    public let narrationTravelDistanceMiles: Double

    /// Estimated distance from POI when narration completes (in miles).
    public let distanceFromPOIOnCompletionMiles: Double

    /// Whether this timing is valid (user won't pass POI before narration ends).
    public let isValid: Bool

    public init(
        triggerDistanceMiles: Double,
        currentSpeedMph: Double,
        timeToTriggerSeconds: Double,
        narrationTravelDistanceMiles: Double,
        distanceFromPOIOnCompletionMiles: Double,
        isValid: Bool
    ) {
        self.triggerDistanceMiles = triggerDistanceMiles
        self.currentSpeedMph = currentSpeedMph
        self.timeToTriggerSeconds = timeToTriggerSeconds
        self.narrationTravelDistanceMiles = narrationTravelDistanceMiles
        self.distanceFromPOIOnCompletionMiles = distanceFromPOIOnCompletionMiles
        self.isValid = isValid
    }
}

/// Protocol for calculating narration timing.
public protocol NarrationTimingCalculator: Sendable {
    /// Calculates when to trigger a narration based on current conditions.
    ///
    /// - Parameters:
    ///   - narration: The narration to schedule
    ///   - distanceFromPOIMiles: Current distance from the POI
    ///   - currentSpeedMph: Current vehicle speed
    ///   - targetArrivalWindowSeconds: Desired time window to arrive at POI after narration (default 60-120 seconds)
    /// - Returns: Timing information for the narration
    func calculateTiming(
        for narration: Narration,
        distanceFromPOIMiles: Double,
        currentSpeedMph: Double,
        targetArrivalWindowSeconds: ClosedRange<Double>
    ) -> NarrationTiming
}

/// Standard implementation of narration timing calculator.
public struct StandardNarrationTimingCalculator: NarrationTimingCalculator {
    /// Average speaking rate in words per minute.
    private let wordsPerMinute: Double

    /// Minimum safe distance before POI to start narration (miles).
    private let minimumTriggerDistanceMiles: Double

    public init(
        wordsPerMinute: Double = 150.0,
        minimumTriggerDistanceMiles: Double = 0.5
    ) {
        self.wordsPerMinute = wordsPerMinute
        self.minimumTriggerDistanceMiles = minimumTriggerDistanceMiles
    }

    public func calculateTiming(
        for narration: Narration,
        distanceFromPOIMiles: Double,
        currentSpeedMph: Double,
        targetArrivalWindowSeconds: ClosedRange<Double> = 60...120
    ) -> NarrationTiming {
        // Calculate narration duration
        let narrationDurationSeconds = narration.durationSeconds

        // Calculate distance traveled during narration
        let narrationTravelDistanceMiles = (currentSpeedMph * narrationDurationSeconds) / 3600.0

        // Calculate ideal trigger distance:
        // Should complete narration 1-2 minutes before arriving at POI
        let targetTimeBeforePOISeconds = targetArrivalWindowSeconds.lowerBound
        let distanceToTravelAfterNarrationMiles = (currentSpeedMph * targetTimeBeforePOISeconds) / 3600.0

        let idealTriggerDistance = narrationTravelDistanceMiles + distanceToTravelAfterNarrationMiles

        // Use the greater of ideal distance or minimum safe distance
        let triggerDistance = max(idealTriggerDistance, minimumTriggerDistanceMiles)

        // Calculate time to trigger
        let distanceUntilTrigger = distanceFromPOIMiles - triggerDistance
        let timeToTriggerSeconds = distanceUntilTrigger > 0
            ? (distanceUntilTrigger / currentSpeedMph) * 3600.0
            : 0

        // Calculate where user will be when narration completes
        let distanceFromPOIOnCompletion = distanceFromPOIMiles - narrationTravelDistanceMiles

        // Validate timing - narration should complete before reaching POI
        let isValid = distanceFromPOIOnCompletion > 0 && triggerDistance <= distanceFromPOIMiles

        return NarrationTiming(
            triggerDistanceMiles: triggerDistance,
            currentSpeedMph: currentSpeedMph,
            timeToTriggerSeconds: max(timeToTriggerSeconds, 0),
            narrationTravelDistanceMiles: narrationTravelDistanceMiles,
            distanceFromPOIOnCompletionMiles: distanceFromPOIOnCompletion,
            isValid: isValid
        )
    }
}

/// Protocol for generating AI narration content.
public protocol AIContentGenerator: Sendable {
    /// Generates narration content for a POI.
    ///
    /// - Parameters:
    ///   - poi: Point of interest to narrate about
    ///   - targetDurationSeconds: Desired narration length
    ///   - userInterests: User's interests for personalization
    /// - Returns: Generated narration
    func generateNarration(
        for poi: POI,
        targetDurationSeconds: Double,
        userInterests: Set<UserInterest>
    ) async throws -> Narration
}

/// Error types for narration generation.
public enum NarrationError: Error, LocalizedError {
    case generationFailed(String)
    case invalidPOI
    case noContentAvailable
    case timingInvalid

    public var errorDescription: String? {
        switch self {
        case .generationFailed(let message):
            return "Narration generation failed: \(message)"
        case .invalidPOI:
            return "Invalid POI provided"
        case .noContentAvailable:
            return "No content available for this location"
        case .timingInvalid:
            return "Cannot calculate valid timing for narration"
        }
    }
}

/// Simple mock content generator for testing and demo.
public struct MockContentGenerator: AIContentGenerator {
    private let wordsPerMinute: Double

    public init(wordsPerMinute: Double = 150.0) {
        self.wordsPerMinute = wordsPerMinute
    }

    public func generateNarration(
        for poi: POI,
        targetDurationSeconds: Double,
        userInterests: Set<UserInterest>
    ) async throws -> Narration {
        // Generate simple content based on POI
        var content = ""

        if poi.category == .waterfall {
            content = """
            You're approaching \(poi.name), one of the most spectacular waterfalls in the region. \
            This \(poi.description ?? "natural wonder") has been a popular destination for visitors for generations. \
            The falls cascade down multiple tiers, creating a breathtaking display of nature's power and beauty. \
            Keep an eye out for the viewing area on your right, where you can stop for photos and take in the full majesty of the falls.
            """
        } else if poi.category == .park {
            content = """
            Coming up on your right is \(poi.name). \
            This beautiful \(poi.category.rawValue.lowercased()) offers a peaceful retreat from the road. \
            \(poi.description ?? "Visitors enjoy the tranquil atmosphere and well-maintained grounds.") \
            It's a perfect spot to stretch your legs and enjoy the outdoors.
            """
        } else if poi.category == .restaurant || poi.category == .cafe {
            content = """
            Just ahead you'll find \(poi.name), a local favorite known for \(poi.description ?? "great food"). \
            With an average rating of \(poi.rating.map { String(format: "%.1f", $0.averageRating) } ?? "excellent") stars, \
            this is one of the most popular dining spots in the area. \
            If you're looking for a bite to eat, this could be your stop!
            """
        } else {
            content = """
            You're approaching \(poi.name), a notable \(poi.category.rawValue.lowercased()) in this area. \
            \(poi.description ?? "This location is worth a visit if you have time.") \
            \(poi.rating.map { "Rated \(String(format: "%.1f", $0.averageRating)) stars by visitors." } ?? "") \
            Watch for signs on your right if you'd like to stop and explore.
            """
        }

        // Trim or expand content to match target duration roughly
        let actualWordCount = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let actualDuration = (Double(actualWordCount) / wordsPerMinute) * 60.0

        return Narration(
            poiId: poi.id,
            poiName: poi.name,
            title: "About \(poi.name)",
            content: content,
            durationSeconds: actualDuration,
            source: "Mock Generator"
        )
    }
}

/// Manages a queue of narrations for a tour.
public actor NarrationQueue {
    private var narrations: [Narration] = []
    private var currentNarration: Narration?

    public init() {}

    /// Adds narrations for all POIs in a tour.
    public func enqueue(_ narrations: [Narration]) {
        self.narrations.append(contentsOf: narrations)
    }

    /// Gets the next narration to play.
    public func next() -> Narration? {
        guard let index = narrations.firstIndex(where: { $0.status == .queued || $0.status == .scheduled }) else {
            return nil
        }
        currentNarration = narrations[index]
        return currentNarration
    }

    /// Updates status of a narration.
    public func updateStatus(_ narrationId: UUID, status: NarrationStatus) {
        if let index = narrations.firstIndex(where: { $0.id == narrationId }) {
            narrations[index].status = status

            if status == .playing {
                narrations[index].startedAt = Date()
            } else if status == .completed || status == .skipped {
                narrations[index].completedAt = Date()
            }
        }
    }

    /// Gets all queued narrations.
    public func all() -> [Narration] {
        narrations
    }

    /// Gets current playing narration.
    public func current() -> Narration? {
        currentNarration
    }

    /// Clears all narrations.
    public func clear() {
        narrations.removeAll()
        currentNarration = nil
    }

    /// Gets count of pending narrations.
    public func pendingCount() -> Int {
        narrations.filter { $0.status == .queued || $0.status == .scheduled }.count
    }
}

/// Playback state for narration audio.
public enum NarrationPlaybackState: String, Codable, Sendable {
    case idle = "Idle"
    case preparing = "Preparing"
    case playing = "Playing"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
}

/// Protocol for synthesizing and playing narration audio.
public protocol NarrationAudioService: Sendable {
    /// Prepares audio for a narration without starting playback.
    ///
    /// - Parameter narration: The narration to prepare
    /// - Throws: `NarrationError` if preparation fails
    func prepare(_ narration: Narration) async throws

    /// Plays narration audio.
    ///
    /// - Parameter narration: The narration to play
    /// - Throws: `NarrationError` if playback fails
    func play(_ narration: Narration) async throws

    /// Pauses current playback.
    func pause() async

    /// Resumes paused playback.
    func resume() async

    /// Stops current playback.
    func stop() async

    /// Gets current playback state.
    var playbackState: NarrationPlaybackState { get async }

    /// Gets current narration being played.
    var currentNarration: Narration? { get async }
}

/// Error types for narration audio.
public enum NarrationAudioError: Error, LocalizedError {
    case synthesisFailure(String)
    case playbackFailure(String)
    case audioSessionFailure(String)
    case noAudioPrepared

    public var errorDescription: String? {
        switch self {
        case .synthesisFailure(let message):
            return "Audio synthesis failed: \(message)"
        case .playbackFailure(let message):
            return "Audio playback failed: \(message)"
        case .audioSessionFailure(let message):
            return "Audio session error: \(message)"
        case .noAudioPrepared:
            return "No audio prepared for playback"
        }
    }
}

/// Mock narration audio service for testing.
public actor MockNarrationAudioService: NarrationAudioService {
    public var _playbackState: NarrationPlaybackState = .idle
    public var _currentNarration: Narration?
    public var prepareCallCount = 0
    public var playCallCount = 0
    public var pauseCallCount = 0
    public var resumeCallCount = 0
    public var stopCallCount = 0

    public init() {}

    public func prepare(_ narration: Narration) async throws {
        prepareCallCount += 1
        _currentNarration = narration
        _playbackState = .idle
    }

    public func play(_ narration: Narration) async throws {
        playCallCount += 1
        _currentNarration = narration
        _playbackState = .playing

        // Simulate playback completing after a short delay
        try? await Task.sleep(for: .milliseconds(100))
        _playbackState = .completed
        _currentNarration = nil
    }

    public func pause() async {
        pauseCallCount += 1
        guard _playbackState == .playing else { return }
        _playbackState = .paused
    }

    public func resume() async {
        resumeCallCount += 1
        guard _playbackState == .paused else { return }
        _playbackState = .playing
    }

    public func stop() async {
        stopCallCount += 1
        _playbackState = .idle
        _currentNarration = nil
    }

    public var playbackState: NarrationPlaybackState {
        get async { _playbackState }
    }

    public var currentNarration: Narration? {
        get async { _currentNarration }
    }

    // Test helpers
    public func setState(_ state: NarrationPlaybackState) {
        _playbackState = state
    }

    public func setNarration(_ narration: Narration?) {
        _currentNarration = narration
    }
}
