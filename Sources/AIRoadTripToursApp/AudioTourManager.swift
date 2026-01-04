import Foundation
import Observation
import AVFoundation
import AIRoadTripToursCore
import AIRoadTripToursServices

/// Error thrown when an operation times out
struct TimeoutError: Error {
    let seconds: Double
}

/// Executes an async operation with a timeout
func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError(seconds: seconds)
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

/// Manages audio tour playback state across the app.
@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
public final class AudioTourManager {

    #if canImport(UIKit)
    private let audioService = AVSpeechNarrationAudioService()
    private let voiceService = VoiceInteractionService()
    #endif
    private let proximityMonitor = ProximityMonitor()
    private let imageService = POIImageService()

    public var currentNarration: Narration?
    public var playbackState: NarrationPlaybackState = .idle
    public var isGenerating = false
    public var isPrepared = false
    public var isMonitoring = false

    public var currentPOIs: [POI] = []
    public var currentPOIImages: [UUID: [POIImage]] = [:] // POI.id -> images
    public var sessions: [NarrationSession] = []
    public var currentSessionIndex = 0

    private var monitoringTask: Task<Void, Never>?
    private var userInterests: Set<UserInterest> = []

    // Tour history tracking
    private var tourStartTime: Date?
    private var tourName: String?
    private var routeCoordinates: [GeoLocation] = []
    private weak var tourHistoryStorage: TourHistoryStorage?

    public init(tourHistoryStorage: TourHistoryStorage? = nil) {
        self.tourHistoryStorage = tourHistoryStorage
    }

    // MARK: - Tour Control

    /// Prepares the tour by loading content but doesn't start playback.
    /// Playback will start automatically when first POI is nearby.
    public func startTour(pois: [POI], userInterests: Set<UserInterest>) async {
        // Stop any existing tour
        await stopTour()

        isGenerating = true
        currentPOIs = pois
        self.userInterests = userInterests
        defer { isGenerating = false }

        // Initialize tour tracking
        tourStartTime = Date()
        tourName = pois.count == 1 ? pois[0].name : "\(pois.count) POI Tour"
        routeCoordinates = []

        // Load images for all POIs in parallel
        await loadImagesForPOIs(pois)

        // Create sessions for each POI
        sessions = pois.map { poi in
            NarrationSession(poi: poi)
        }

        currentSessionIndex = 0
        isPrepared = true
        playbackState = .preparing

        print("✅ Tour prepared with \(pois.count) POIs. Waiting for proximity to first POI...")
    }

    /// Starts monitoring user location and triggers narrations based on proximity.
    public func startLocationMonitoring(userLocation: GeoLocation, speed: Double?) async {
        guard isPrepared, !isMonitoring else { return }

        isMonitoring = true

        monitoringTask?.cancel()
        monitoringTask = Task {
            while !Task.isCancelled && isPrepared {
                await checkProximityAndTrigger(userLocation: userLocation, speed: speed)
                try? await Task.sleep(for: .seconds(5)) // Check every 5 seconds
            }
        }
    }

    public func stopTour() async {
        // Record tour history if tour was in progress
        if isPrepared, tourStartTime != nil {
            await recordTourCompletion(completed: false)
        }

        // Cancel monitoring task
        monitoringTask?.cancel()
        monitoringTask = nil

        #if canImport(UIKit)
        await audioService.stop()
        await voiceService.stopListening()
        #endif

        currentNarration = nil
        playbackState = .idle
        currentPOIs = []
        currentPOIImages = [:]
        sessions = []
        currentSessionIndex = 0
        isPrepared = false
        isMonitoring = false

        // Clear tour tracking
        tourStartTime = nil
        tourName = nil
        routeCoordinates = []
    }

    public func pauseResume() async {
        #if canImport(UIKit)
        switch playbackState {
        case .playing:
            await audioService.pause()
        case .paused:
            await audioService.resume()
        default:
            break
        }
        #endif
    }

    public func skip() async {
        #if canImport(UIKit)
        await audioService.stop()
        #endif

        // Mark current session phase as skipped
        if currentSessionIndex < sessions.count {
            sessions[currentSessionIndex].currentPhase = .passed
        }

        // Move to next POI
        currentSessionIndex += 1
        if currentSessionIndex >= sessions.count {
            playbackState = .completed
            currentNarration = nil
        }
    }

    // MARK: - Proximity Monitoring

    private func checkProximityAndTrigger(userLocation: GeoLocation, speed: Double?) async {
        // Record route coordinate
        routeCoordinates.append(userLocation)

        guard currentSessionIndex < sessions.count else {
            // Tour completed - all POIs visited
            playbackState = .completed
            await recordTourCompletion(completed: true)
            return
        }

        var session = sessions[currentSessionIndex]

        // Update proximity info
        await proximityMonitor.updateSession(&session, currentLocation: userLocation, currentSpeed: speed)
        sessions[currentSessionIndex] = session

        // Determine next phase
        let nextPhase = await proximityMonitor.determineNextPhase(for: session)

        // Trigger narration if phase changed
        if nextPhase != session.currentPhase {
            sessions[currentSessionIndex].currentPhase = nextPhase
            await handlePhaseChange(session: sessions[currentSessionIndex], phase: nextPhase)
        }
    }

    private func handlePhaseChange(session: NarrationSession, phase: NarrationPhase) async {
        switch phase {
        case .approaching:
            await playTeaserNarration(for: session)

        case .detailed:
            await playDetailedNarration(for: session)

        case .arrival:
            await playArrivalPrompt(for: session)

        case .guidedTour:
            await playGuidedTour(for: session)

        case .passed:
            print("User passed \(session.poi.name) without stopping")
            currentSessionIndex += 1

        case .pending:
            break
        }
    }

    private func playTeaserNarration(for session: NarrationSession) async {
        #if canImport(UIKit)
        do {
            playbackState = .playing

            // Generate teaser (3-5 min ETA, brief overview) with timeout
            let generator = EnrichedContentGenerator()

            let teaserNarration = try await withTimeout(seconds: 30.0) {
                try await generator.generateNarration(
                    for: session.poi,
                    targetDurationSeconds: 30.0,
                    userInterests: userInterests
                )
            }

            currentNarration = teaserNarration
            sessions[currentSessionIndex].teaserPlayed = true

            try await audioService.play(teaserNarration)

            // After teaser, ask if user wants to hear more
            await askForContinuation()

        } catch is TimeoutError {
            print("Timeout generating teaser for \(session.poi.name), skipping...")
            playbackState = .idle
            sessions[currentSessionIndex].currentPhase = .passed
            currentSessionIndex += 1
        } catch {
            print("Error playing teaser: \(error)")
            playbackState = .failed
        }
        #endif
    }

    private func askForContinuation() async {
        #if canImport(UIKit)
        do {
            // Create prompt narration
            let promptNarration = Narration(
                id: UUID(),
                poiId: sessions[currentSessionIndex].poi.id,
                poiName: sessions[currentSessionIndex].poi.name,
                title: "Would you like to hear more?",
                content: "Would you like to hear more details about \(sessions[currentSessionIndex].poi.name)? Say yes to continue or no to skip.",
                durationSeconds: 5.0,
                source: "System"
            )

            try await audioService.play(promptNarration)

            // Listen for response
            let response = await voiceService.listenForResponse(timeout: 10.0)

            sessions[currentSessionIndex].userWantsMore = (response == .yes)

            if response != .yes {
                print("User declined detailed narration")
                sessions[currentSessionIndex].currentPhase = .passed
                currentSessionIndex += 1
            }

        } catch {
            print("Error in continuation prompt: \(error)")
            // Assume no if error
            sessions[currentSessionIndex].userWantsMore = false
        }
        #endif
    }

    private func playDetailedNarration(for session: NarrationSession) async {
        #if canImport(UIKit)
        do {
            playbackState = .playing

            // Generate detailed narration (1-2 min ETA) with timeout
            let generator = EnrichedContentGenerator()

            let detailedNarration = try await withTimeout(seconds: 45.0) {
                try await generator.generateNarration(
                    for: session.poi,
                    targetDurationSeconds: 90.0,
                    userInterests: userInterests
                )
            }

            currentNarration = detailedNarration
            sessions[currentSessionIndex].detailedPlayed = true

            try await audioService.play(detailedNarration)

        } catch is TimeoutError {
            print("Timeout generating detailed narration for \(session.poi.name), skipping...")
            playbackState = .idle
            sessions[currentSessionIndex].currentPhase = .passed
            currentSessionIndex += 1
        } catch {
            print("Error playing detailed narration: \(error)")
            playbackState = .failed
        }
        #endif
    }

    private func playArrivalPrompt(for session: NarrationSession) async {
        #if canImport(UIKit)
        do {
            playbackState = .playing

            // Brief arrival message
            let arrivalNarration = Narration(
                id: UUID(),
                poiId: session.poi.id,
                poiName: session.poi.name,
                title: "You've arrived!",
                content: "You've arrived at \(session.poi.name). Would you like a guided tour? Say yes or no.",
                durationSeconds: 5.0,
                source: "System"
            )

            currentNarration = arrivalNarration
            sessions[currentSessionIndex].arrivalPromptPlayed = true

            try await audioService.play(arrivalNarration)

            // Listen for response
            let response = await voiceService.listenForResponse(timeout: 10.0)

            sessions[currentSessionIndex].userWantsTour = (response == .yes)

            if response == .yes {
                sessions[currentSessionIndex].currentPhase = .guidedTour
                await playGuidedTour(for: sessions[currentSessionIndex])
            } else {
                // Move to next POI
                currentSessionIndex += 1
            }

        } catch {
            print("Error in arrival prompt: \(error)")
            currentSessionIndex += 1
        }
        #endif
    }

    private func playGuidedTour(for session: NarrationSession) async {
        #if canImport(UIKit)
        do {
            playbackState = .playing

            // Generate comprehensive guided tour
            let generator = EnrichedContentGenerator()
            let tourNarration = try await generator.generateNarration(
                for: session.poi,
                targetDurationSeconds: 180.0,
                userInterests: userInterests
            )

            currentNarration = tourNarration

            try await audioService.play(tourNarration)

            // Guided tour complete, move to next POI
            currentSessionIndex += 1

        } catch {
            print("Error playing guided tour: \(error)")
            playbackState = .failed
        }
        #endif
    }

    // MARK: - Images

    public func getImagesForCurrentPOI() -> [POIImage] {
        guard let current = currentNarration else { return [] }

        // Find the POI that matches the current narration
        guard let poi = currentPOIs.first(where: { $0.id == current.poiId }) else {
            return []
        }

        return currentPOIImages[poi.id] ?? []
    }

    private func loadImagesForPOIs(_ pois: [POI]) async {
        await withTaskGroup(of: (UUID, [POIImage]).self) { group in
            for poi in pois {
                group.addTask {
                    do {
                        let images = try await self.imageService.fetchImages(for: poi, limit: 5)
                        return (poi.id, images)
                    } catch {
                        return (poi.id, [])
                    }
                }
            }

            for await (poiId, images) in group {
                currentPOIImages[poiId] = images
            }
        }
    }

    // MARK: - State Monitoring

    public func startMonitoring() async {
        #if canImport(UIKit)
        while true {
            playbackState = await audioService.playbackState
            try? await Task.sleep(for: .milliseconds(100))
        }
        #endif
    }

    // MARK: - Tour History

    private func recordTourCompletion(completed: Bool) async {
        guard let storage = tourHistoryStorage,
              let startTime = tourStartTime,
              let name = tourName,
              !currentPOIs.isEmpty else {
            return
        }

        let endTime = Date()
        let durationMinutes = Int(endTime.timeIntervalSince(startTime) / 60.0)

        // Calculate total distance traveled
        var totalDistance = 0.0
        for i in 1..<routeCoordinates.count {
            totalDistance += routeCoordinates[i-1].distance(to: routeCoordinates[i])
        }

        // Count POIs that were actually visited (passed phase or completed)
        let poisVisited = sessions.filter { session in
            session.currentPhase == .passed || session.currentPhase == .guidedTour
        }.count

        // Create tour ID from first POI if exists
        let tourId = currentPOIs.first?.id ?? UUID()

        let entry = TourHistoryEntry(
            tourId: tourId,
            tourName: name,
            completedAt: endTime,
            durationMinutes: durationMinutes,
            distanceMiles: totalDistance,
            poisVisited: poisVisited,
            routeCoordinates: routeCoordinates
        )

        storage.addEntry(entry)
        print("✅ Tour recorded: \(name), \(poisVisited) POIs, \(String(format: "%.1f", totalDistance)) miles, \(durationMinutes) minutes")
    }
}
