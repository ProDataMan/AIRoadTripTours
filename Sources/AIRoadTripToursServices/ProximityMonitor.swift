import Foundation
import AIRoadTripToursCore

/// Monitors proximity to POIs and determines when to trigger narrations.
@available(iOS 17.0, macOS 14.0, *)
public actor ProximityMonitor {

    /// Average driving speed in mph (used when actual speed unavailable)
    private let defaultSpeed: Double = 45.0

    public init() {}

    /// Calculates estimated time to arrival in seconds.
    public func estimatedTimeToArrival(
        from currentLocation: GeoLocation,
        to poi: POI,
        currentSpeed: Double?
    ) -> TimeInterval {
        let distanceMiles = currentLocation.distance(to: poi.location)
        let speed = currentSpeed ?? defaultSpeed

        guard speed > 0 else {
            return .infinity // Stationary
        }

        let hours = distanceMiles / speed
        return hours * 3600 // Convert to seconds
    }

    /// Determines if teaser narration should be triggered.
    /// Triggers when 3-5 minutes away from POI.
    public func shouldTriggerTeaser(
        distanceMiles: Double,
        eta: TimeInterval
    ) -> Bool {
        // Trigger between 3-5 minutes (180-300 seconds)
        return eta >= 180 && eta <= 300 && !eta.isInfinite
    }

    /// Determines if detailed narration should be triggered.
    /// Triggers when 1-2 minutes away from POI.
    public func shouldTriggerDetailed(
        distanceMiles: Double,
        eta: TimeInterval
    ) -> Bool {
        // Trigger between 1-2 minutes (60-120 seconds)
        return eta >= 60 && eta <= 120 && !eta.isInfinite
    }

    /// Determines if arrival prompt should be triggered.
    /// Triggers when < 1 minute away from POI.
    public func shouldTriggerArrival(
        distanceMiles: Double,
        eta: TimeInterval
    ) -> Bool {
        // Trigger when less than 1 minute (< 60 seconds) or within 0.5 miles
        return (eta < 60 && !eta.isInfinite) || distanceMiles < 0.5
    }

    /// Determines if user has passed the POI.
    /// This happens when distance starts increasing after being close.
    public func hasPassedPOI(
        currentDistance: Double,
        previousDistance: Double
    ) -> Bool {
        // User passed if distance is increasing and they were close
        return currentDistance > previousDistance && previousDistance < 0.5
    }

    /// Updates narration session with current proximity info.
    public func updateSession(
        _ session: inout NarrationSession,
        currentLocation: GeoLocation,
        currentSpeed: Double?
    ) {
        session.distanceToPOI = currentLocation.distance(to: session.poi.location)
        session.estimatedTimeToArrival = estimatedTimeToArrival(
            from: currentLocation,
            to: session.poi,
            currentSpeed: currentSpeed
        )
    }

    /// Determines next phase based on current proximity.
    public func determineNextPhase(
        for session: NarrationSession
    ) -> NarrationPhase {
        let distance = session.distanceToPOI
        let eta = session.estimatedTimeToArrival

        // Already in guided tour
        if session.currentPhase == .guidedTour {
            return .guidedTour
        }

        // User passed POI
        if session.currentPhase != .pending && distance > 2.0 {
            return .passed
        }

        // Check if should trigger arrival
        if !session.arrivalPromptPlayed &&
           session.detailedPlayed &&
           shouldTriggerArrival(distanceMiles: distance, eta: eta) {
            return .arrival
        }

        // Check if should trigger detailed
        if !session.detailedPlayed &&
           session.teaserPlayed &&
           session.userWantsMore == true &&
           shouldTriggerDetailed(distanceMiles: distance, eta: eta) {
            return .detailed
        }

        // Check if should trigger teaser
        if !session.teaserPlayed &&
           shouldTriggerTeaser(distanceMiles: distance, eta: eta) {
            return .approaching
        }

        return session.currentPhase
    }
}
