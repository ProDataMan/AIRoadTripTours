import Foundation

/// Phases of an interactive audio tour narration.
public enum NarrationPhase: String, Codable, Sendable {
    /// 3-5 minutes away: Brief teaser narration
    case approaching = "Approaching"

    /// 1-2 minutes away: Full detailed narration
    case detailed = "Detailed"

    /// < 1 minute away: Guided tour offer
    case arrival = "Arrival"

    /// On-site: Detailed guided tour
    case guidedTour = "Guided Tour"

    /// User passed POI without stopping
    case passed = "Passed"

    /// Not yet triggered
    case pending = "Pending"
}

/// User's response to a narration prompt.
public enum UserResponse: String, Codable, Sendable {
    case yes = "Yes"
    case no = "No"
    case noResponse = "No Response"
}

/// State of an interactive narration session.
public struct NarrationSession: Identifiable, Codable, Sendable {
    public let id: UUID
    public let poi: POI
    public var currentPhase: NarrationPhase
    public var teaserPlayed: Bool
    public var detailedPlayed: Bool
    public var arrivalPromptPlayed: Bool
    public var userWantsMore: Bool?
    public var userWantsTour: Bool?
    public var distanceToPOI: Double // miles
    public var estimatedTimeToArrival: TimeInterval // seconds

    public init(
        id: UUID = UUID(),
        poi: POI,
        currentPhase: NarrationPhase = .pending,
        teaserPlayed: Bool = false,
        detailedPlayed: Bool = false,
        arrivalPromptPlayed: Bool = false,
        userWantsMore: Bool? = nil,
        userWantsTour: Bool? = nil,
        distanceToPOI: Double = 0,
        estimatedTimeToArrival: TimeInterval = 0
    ) {
        self.id = id
        self.poi = poi
        self.currentPhase = currentPhase
        self.teaserPlayed = teaserPlayed
        self.detailedPlayed = detailedPlayed
        self.arrivalPromptPlayed = arrivalPromptPlayed
        self.userWantsMore = userWantsMore
        self.userWantsTour = userWantsTour
        self.distanceToPOI = distanceToPOI
        self.estimatedTimeToArrival = estimatedTimeToArrival
    }
}
