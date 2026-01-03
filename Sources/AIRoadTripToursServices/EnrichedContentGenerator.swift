import Foundation
import AIRoadTripToursCore

/// Generates compelling narrations using web-enriched POI data.
@available(iOS 17.0, macOS 14.0, *)
public actor EnrichedContentGenerator {

    private let enrichmentService: WikipediaEnrichmentService

    public init(enrichmentService: WikipediaEnrichmentService = WikipediaEnrichmentService()) {
        self.enrichmentService = enrichmentService
    }

    public func generateNarration(
        for poi: POI,
        targetDurationSeconds: Double,
        userInterests: Set<UserInterest>
    ) async throws -> Narration {

        // Enrich POI with Wikipedia data
        let enrichment = try await enrichmentService.enrichPOI(poi)

        // Build engaging narration content
        let content = buildDetailedNarration(
            poi: poi,
            enrichment: enrichment,
            targetDuration: targetDurationSeconds,
            interests: userInterests
        )

        return Narration(
            id: UUID(),
            poiId: poi.id,
            poiName: poi.name,
            title: "Discovering \(poi.name)",
            content: content,
            durationSeconds: targetDurationSeconds,
            source: "Wikipedia + AI"
        )
    }

    /// Generate a brief 30-second "teaser" narration for passive discovery mode.
    public func generateTeaserNarration(for enrichedPOI: EnrichedPOI) async -> Narration {
        let poi = enrichedPOI.poi
        let enrichment = enrichedPOI.enrichment

        var content = "Coming up on your route: \(poi.name). "

        // Add most interesting fact
        if let firstFact = enrichment.historicalFacts.first {
            content += firstFact + ". "
        } else if !enrichment.webSummary.isEmpty {
            // Use first sentence of summary
            let firstSentence = enrichment.webSummary.components(separatedBy: ". ").first ?? enrichment.webSummary
            content += firstSentence + ". "
        }

        content += "Would you like to hear more?"

        return Narration(
            id: UUID(),
            poiId: poi.id,
            poiName: poi.name,
            title: "Teaser: \(poi.name)",
            content: content,
            durationSeconds: 30.0,
            source: "Wikipedia + AI"
        )
    }

    /// Generate a comprehensive narration with all available enriched data.
    public func generateDetailedNarration(for enrichedPOI: EnrichedPOI) async -> Narration {
        let poi = enrichedPOI.poi
        let enrichment = enrichedPOI.enrichment

        let content = buildDetailedNarration(
            poi: poi,
            enrichment: enrichment,
            targetDuration: 120.0, // 2 minutes for detailed
            interests: []
        )

        return Narration(
            id: UUID(),
            poiId: poi.id,
            poiName: poi.name,
            title: "Deep Dive: \(poi.name)",
            content: content,
            durationSeconds: 120.0,
            source: "Wikipedia + AI"
        )
    }

    // MARK: - Private Helpers

    private func buildDetailedNarration(
        poi: POI,
        enrichment: POIEnrichment,
        targetDuration: Double,
        interests: Set<UserInterest>
    ) -> String {
        var sections: [String] = []

        // Opening: Introduce the POI
        sections.append(buildOpening(poi: poi))

        // Main content: Web summary
        if !enrichment.webSummary.isEmpty {
            sections.append(enrichment.webSummary)
        }

        // Historical facts (prioritize based on interests)
        if !enrichment.historicalFacts.isEmpty {
            let facts = prioritizeFacts(enrichment.historicalFacts, for: interests)
            sections.append("\n\nHere are some fascinating facts: " + facts.joined(separator: ". ") + ".")
        }

        // Interesting stories
        if !enrichment.interestingStories.isEmpty {
            sections.append("\n\n" + enrichment.interestingStories.joined(separator: " "))
        }

        // Visit tips
        if !enrichment.visitTips.isEmpty {
            sections.append("\n\nIf you're planning to visit: " + enrichment.visitTips.joined(separator: ". ") + ".")
        }

        // Closing
        sections.append(buildClosing(poi: poi))

        // Combine and trim to target duration
        let fullContent = sections.joined(separator: " ")
        return trimToTargetDuration(fullContent, targetDuration: targetDuration)
    }

    private func buildOpening(poi: POI) -> String {
        let greetings = [
            "Let me tell you about \(poi.name).",
            "Here's something interesting about \(poi.name).",
            "You're approaching \(poi.name).",
            "Welcome to \(poi.name)."
        ]
        return greetings.randomElement() ?? greetings[0]
    }

    private func buildClosing(poi: POI) -> String {
        return "That's the story of \(poi.name). Enjoy your visit!"
    }

    private func prioritizeFacts(_ facts: [String], for interests: Set<UserInterest>) -> [String] {
        // If user has history interest, prioritize historical facts
        let hasHistoryInterest = interests.contains { $0.name.lowercased().contains("history") }

        if hasHistoryInterest {
            return facts
        }

        // Otherwise return first few facts
        return Array(facts.prefix(3))
    }

    private func trimToTargetDuration(_ content: String, targetDuration: Double) -> String {
        // Average speaking rate: ~150 words per minute = 2.5 words per second
        let targetWordCount = Int(targetDuration * 2.5)

        let words = content.split(separator: " ")
        if words.count <= targetWordCount {
            return content
        }

        // Trim to target word count and add ellipsis
        let trimmedWords = words.prefix(targetWordCount)
        return trimmedWords.joined(separator: " ") + "..."
    }
}
