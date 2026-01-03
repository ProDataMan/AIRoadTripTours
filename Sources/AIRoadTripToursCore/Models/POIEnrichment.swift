import Foundation

/// Enhanced POI information sourced from web searches and external APIs.
public struct POIEnrichment: Codable, Sendable {
    /// Comprehensive summary of the POI
    public let webSummary: String

    /// Key historical facts and interesting information
    public let historicalFacts: [String]

    /// Practical tips for visiting (parking, hours, best times)
    public let visitTips: [String]

    /// Compelling stories and narratives about the location
    public let interestingStories: [String]

    /// Source URLs for attribution
    public let sources: [String]

    /// When this enrichment data was fetched
    public let enrichedAt: Date

    public init(
        webSummary: String,
        historicalFacts: [String],
        visitTips: [String],
        interestingStories: [String],
        sources: [String],
        enrichedAt: Date
    ) {
        self.webSummary = webSummary
        self.historicalFacts = historicalFacts
        self.visitTips = visitTips
        self.interestingStories = interestingStories
        self.sources = sources
        self.enrichedAt = enrichedAt
    }

    /// Returns true if this enrichment data is stale (older than 30 days)
    public var isStale: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return enrichedAt < thirtyDaysAgo
    }
}

/// POI with enriched web-sourced data.
public struct EnrichedPOI: Codable, Sendable, Identifiable {
    public let id: UUID
    public let poi: POI
    public let enrichment: POIEnrichment
    public let routeContext: RouteContext?

    public init(
        id: UUID = UUID(),
        poi: POI,
        enrichment: POIEnrichment,
        routeContext: RouteContext? = nil
    ) {
        self.id = id
        self.poi = poi
        self.enrichment = enrichment
        self.routeContext = routeContext
    }
}

/// Context about a POI's relationship to a planned route.
public struct RouteContext: Codable, Sendable {
    /// Distance in miles from the main route
    public let distanceFromRoute: Double

    /// Additional time required to detour to this POI
    public let detourDuration: TimeInterval

    /// Which segment of the route this POI belongs to
    public let segmentIndex: Int

    /// Estimated arrival time at this POI
    public let estimatedArrival: Date

    public init(
        distanceFromRoute: Double,
        detourDuration: TimeInterval,
        segmentIndex: Int,
        estimatedArrival: Date
    ) {
        self.distanceFromRoute = distanceFromRoute
        self.detourDuration = detourDuration
        self.segmentIndex = segmentIndex
        self.estimatedArrival = estimatedArrival
    }
}
