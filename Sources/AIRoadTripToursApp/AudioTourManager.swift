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
func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
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
    public var poisReadyForMap = false  // New flag to signal POIs are loaded

    public var currentPOIs: [POI] = [] {
        didSet {
            print("🗺️ AudioTourManager: currentPOIs changed from \(oldValue.count) to \(currentPOIs.count) POIs")
        }
    }
    public var currentPOIImages: [UUID: [POIImage]] = [:] // POI.id -> images
    public var sessions: [NarrationSession] = [] {
        didSet {
            print("🗺️ AudioTourManager: sessions changed from \(oldValue.count) to \(sessions.count) sessions")
        }
    }
    public var currentSessionIndex = 0

    // For coordinating map zoom during introduction
    public var introducingPOIIndex: Int? = nil {
        didSet {
            print("🗺️ AudioTourManager: introducingPOIIndex changed from \(String(describing: oldValue)) to \(String(describing: introducingPOIIndex))")
            // Post notification to communicate across sheet boundary
            NotificationCenter.default.post(
                name: NSNotification.Name("IntroducingPOIIndexChanged"),
                object: nil,
                userInfo: ["index": introducingPOIIndex as Any]
            )
        }
    }

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

    /// Prepares the tour by loading POIs and sessions, but doesn't start narration.
    /// Returns the prepared POIs and sessions immediately.
    /// Call playWelcomeIntroduction() separately to start narration.
    public func prepareTour(pois: [POI], userInterests: Set<UserInterest>) async -> (pois: [POI], sessions: [NarrationSession]) {
        // Stop any existing tour
        await stopTour()

        isGenerating = true
        currentPOIs = pois
        self.userInterests = userInterests

        // Initialize tour tracking
        tourStartTime = Date()
        tourName = pois.count == 1 ? pois[0].name : "\(pois.count) POI Tour"
        routeCoordinates = []

        // Create sessions immediately (before async image loading)
        sessions = pois.map { poi in
            NarrationSession(poi: poi)
        }

        // POIs and sessions are now ready for map display
        poisReadyForMap = true
        print("🗺️ ✅ POIs and sessions ready for map display")

        // Load images for all POIs in parallel (async, can happen in background)
        await loadImagesForPOIs(pois)

        currentSessionIndex = 0
        isPrepared = true
        playbackState = .preparing
        isGenerating = false

        print("✅ Tour prepared with \(pois.count) POIs")

        // Return the data directly instead of relying on property reads
        return (currentPOIs, sessions)
    }

    /// Prepares the tour and plays welcome introduction (convenience method).
    /// Playback will start automatically when first POI is nearby.
    public func startTour(pois: [POI], userInterests: Set<UserInterest>) async {
        let (preparedPOIs, preparedSessions) = await prepareTour(pois: pois, userInterests: userInterests)
        print("🔊 Playing welcome introduction...")
        await playWelcomeIntroduction(poiCount: preparedPOIs.count, sessionsToIntroduce: preparedSessions)
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
        poisReadyForMap = false

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
            let interests = userInterests

            let teaserNarration = try await withTimeout(seconds: 30.0) {
                try await generator.generateNarration(
                    for: session.poi,
                    targetDurationSeconds: 30.0,
                    userInterests: interests
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

    /// Plays the welcome message and introduces each POI with map zoom coordination.
    /// Should be called after prepareTour() completes.
    /// - Parameters:
    ///   - poiCount: Number of POIs in the tour (passed to avoid timing issues)
    ///   - sessionsToIntroduce: Sessions to introduce (passed to avoid @Observable timing issues)
    public func playWelcomeIntroduction(poiCount: Int? = nil, sessionsToIntroduce: [NarrationSession]? = nil) async {
        #if canImport(UIKit)
        do {
            playbackState = .playing

            // Generate welcome message content
            let welcomeContent = generateWelcomeContent()

            // Create welcome narration
            let welcomeNarration = Narration(
                id: UUID(),
                poiId: UUID(), // Not tied to specific POI
                poiName: "Tour Introduction",
                title: "Welcome to AI Road Trip Tours",
                content: welcomeContent,
                durationSeconds: Double(welcomeContent.count) / 15.0, // ~15 chars per second speech rate
                source: "System"
            )

            currentNarration = welcomeNarration

            try await audioService.play(welcomeNarration)

            // Now introduce each POI individually with map zoom coordination
            let count = poiCount ?? sessions.count
            let overview = "Today's tour includes \(count) fascinating destination\(count == 1 ? "" : "s"). Let me show you each one."

            let overviewIntro = Narration(
                id: UUID(),
                poiId: UUID(),
                poiName: "Tour Overview",
                title: "Today's Tour Overview",
                content: overview,
                durationSeconds: Double(overview.count) / 15.0,
                source: "System"
            )

            currentNarration = overviewIntro
            try await audioService.play(overviewIntro)

            // Introduce each POI with coordinated map zoom
            let sessionsToLoop = sessionsToIntroduce ?? sessions
            print("🗺️ About to introduce \(sessionsToLoop.count) POIs individually")
            for (index, session) in sessionsToLoop.enumerated() {
                await introducePOI(session: session, index: index)
            }

            // Zoom back out to full view
            introducingPOIIndex = nil
            print("🗺️ Zooming out to full tour view")
            try? await Task.sleep(for: .seconds(2))

            // Closing message
            let closingContent = "That's your tour preview! Now, let's begin. The detailed narration will start automatically as you approach each destination. Safe travels!"

            let closingNarration = Narration(
                id: UUID(),
                poiId: UUID(),
                poiName: "Tour Start",
                title: "Let's Begin",
                content: closingContent,
                durationSeconds: Double(closingContent.count) / 15.0,
                source: "System"
            )

            currentNarration = closingNarration
            try await audioService.play(closingNarration)

            // Set playback to idle, waiting for vehicle to start moving
            playbackState = .idle
            currentNarration = nil

            print("✅ Welcome introduction completed. Waiting for proximity to first POI...")

        } catch {
            print("Error playing welcome introduction: \(error)")
            playbackState = .idle
        }
        #endif
    }

    private func introducePOI(session: NarrationSession, index: Int) async {
        #if canImport(UIKit)
        do {
            let poi = session.poi

            // Start zooming to this POI
            introducingPOIIndex = index
            print("🎯 Zooming to POI \(index): \(poi.name)")

            // Wait for zoom animation to complete
            try await Task.sleep(for: .seconds(1.5))

            // Create introduction narration for this POI
            var poiIntro = "Stop number \(index + 1): \(poi.name). "
            poiIntro += "\(poi.category.rawValue). "

            if let description = poi.description, !description.isEmpty {
                let briefDesc = String(description.prefix(150))
                poiIntro += "\(briefDesc). "
            }

            let poiNarration = Narration(
                id: UUID(),
                poiId: poi.id,
                poiName: poi.name,
                title: "POI Introduction",
                content: poiIntro,
                durationSeconds: Double(poiIntro.count) / 15.0,
                source: "System"
            )

            currentNarration = poiNarration
            try await audioService.play(poiNarration)

            // Zoom back out to full view
            introducingPOIIndex = nil
            print("🗺️ Zooming back out to full tour view")

            // Pause before next POI
            try await Task.sleep(for: .seconds(1.5))

        } catch {
            print("Error introducing POI \(session.poi.name): \(error)")
        }
        #endif
    }

    private func generateWelcomeContent() -> String {
        return """
        Welcome to AI Road Trip Tours! Thank you for choosing us for your journey today. \

        We're excited to be your guide on this adventure. Our app uses artificial intelligence to provide you with \
        personalized narration about the fascinating places along your route. \

        As you drive, we'll automatically detect when you're approaching points of interest and share engaging stories, \
        historical facts, and local insights tailored to your interests. \

        The tour narration will begin automatically when your vehicle starts moving and you get close to our first destination. \
        You can pause, skip, or ask for more details at any time using voice commands or the controls on your screen. \

        Now, let me give you a preview of the amazing places we'll be exploring today.
        """
    }

    private func generateTourOverview() -> String {
        guard !sessions.isEmpty else {
            return "Your tour is ready. Start driving to begin exploring!"
        }

        var overview = "Today's tour includes \(sessions.count) fascinating destination\(sessions.count == 1 ? "" : "s"). "

        // List each POI with brief summary
        for (index, session) in sessions.enumerated() {
            let poi = session.poi
            let number = index + 1

            overview += "Stop number \(number): \(poi.name). "

            // Add category context
            overview += "\(poi.category.rawValue). "

            // Add brief description if available
            if let description = poi.description, !description.isEmpty {
                let briefDesc = String(description.prefix(150))
                overview += "\(briefDesc). "
            }
        }

        // Add navigation timing estimates
        overview += "\n\nHere's what to expect for travel times: "

        for (index, session) in sessions.enumerated() {
            let number = index + 1

            // Estimate times (in real implementation, use actual navigation data)
            let travelTime = estimateTravelTime(to: session, fromPreviousIndex: index - 1)
            let tourDuration = estimateTourDuration(for: session)

            if index == 0 {
                let minutes = Int(travelTime / 60)
                overview += "We'll arrive at our first stop, \(session.poi.name), in approximately \(minutes) minute\(minutes == 1 ? "" : "s"). "
                overview += "The tour of that area will take about \(Int(tourDuration / 60)) minutes. "
            } else if index < sessions.count - 1 {
                let minutes = Int(travelTime / 60)
                let nextMinutes = Int(estimateTravelTime(to: sessions[index + 1], fromPreviousIndex: index) / 60)
                overview += "Then, after \(minutes) minute\(minutes == 1 ? "" : "s") of driving, we'll reach \(session.poi.name) for about \(Int(tourDuration / 60)) minutes. "
            } else {
                // Last stop
                let minutes = Int(travelTime / 60)
                overview += "Finally, we'll arrive at our last destination, \(session.poi.name), after \(minutes) more minute\(minutes == 1 ? "" : "s") of travel. "
            }
        }

        overview += "\n\nSit back, relax, and enjoy the journey. The narration will begin automatically as you approach each destination. Safe travels!"

        return overview
    }

    private func estimateTravelTime(to session: NarrationSession, fromPreviousIndex previousIndex: Int) -> TimeInterval {
        // Estimate travel time based on distance
        // Assume average speed of 45 mph on road trips
        let averageSpeedMPH = 45.0
        let distance = session.distanceToPOI

        // If this is not the first POI, estimate from previous POI
        if previousIndex >= 0 && previousIndex < sessions.count {
            let previousPOI = sessions[previousIndex].poi
            let distanceBetween = session.poi.location.distance(to: previousPOI.location)
            let timeInHours = distanceBetween / averageSpeedMPH
            return timeInHours * 3600 // Convert to seconds
        }

        // First POI - use current distance
        let timeInHours = distance / averageSpeedMPH
        return max(timeInHours * 3600, 300) // Minimum 5 minutes
    }

    private func estimateTourDuration(for session: NarrationSession) -> TimeInterval {
        // Estimate 10-15 minutes per POI tour
        return 12 * 60 // 12 minutes average
    }

    private func playDetailedNarration(for session: NarrationSession) async {
        #if canImport(UIKit)
        do {
            playbackState = .playing

            // Generate detailed narration (1-2 min ETA) with timeout
            let generator = EnrichedContentGenerator()
            let interests = userInterests

            let detailedNarration = try await withTimeout(seconds: 45.0) {
                try await generator.generateNarration(
                    for: session.poi,
                    targetDurationSeconds: 90.0,
                    userInterests: interests
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
        guard let current = currentNarration else {
            return []
        }

        // Find the POI that matches the current narration
        guard let poi = currentPOIs.first(where: { $0.id == current.poiId }) else {
            return []
        }

        let images = currentPOIImages[poi.id] ?? []
        return images
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
