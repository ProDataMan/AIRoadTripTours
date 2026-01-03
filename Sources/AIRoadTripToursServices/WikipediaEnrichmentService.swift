import Foundation
import AIRoadTripToursCore

/// Service for enriching POI data with information from Wikipedia and other web sources.
@available(iOS 17.0, macOS 14.0, *)
public actor WikipediaEnrichmentService {

    private let urlSession: URLSession
    private let cache: EnrichmentCache

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.cache = EnrichmentCache()
    }

    /// Enrich a POI with Wikipedia data.
    public func enrichPOI(_ poi: POI) async throws -> POIEnrichment {
        // Check cache first
        if let cached = await cache.get(poiID: poi.id), !cached.isStale {
            return cached
        }

        // Build search query
        let searchQuery = buildSearchQuery(for: poi)

        // Search Wikipedia
        let searchResults = try await searchWikipedia(query: searchQuery)

        guard let firstResult = searchResults.first else {
            // Return minimal enrichment if no results
            return POIEnrichment(
                webSummary: poi.description ?? "No additional information available.",
                historicalFacts: [],
                visitTips: [],
                interestingStories: [],
                sources: [],
                enrichedAt: Date()
            )
        }

        // Fetch full article content
        let article = try await fetchWikipediaArticle(pageID: firstResult.pageID)

        // Extract structured information
        let enrichment = POIEnrichment(
            webSummary: article.extract,
            historicalFacts: extractFacts(from: article),
            visitTips: extractVisitTips(from: article),
            interestingStories: extractStories(from: article),
            sources: [article.url],
            enrichedAt: Date()
        )

        // Cache for future use
        await cache.set(poiID: poi.id, enrichment: enrichment)

        return enrichment
    }

    // MARK: - Wikipedia API Integration

    private func buildSearchQuery(for poi: POI) -> String {
        var query = poi.name

        // Add category context for better search results
        switch poi.category {
        case .waterfall, .park, .beach, .lake:
            query += " nature landmark"
        case .museum, .historicSite:
            query += " history museum"
        case .restaurant, .cafe:
            query += " restaurant food"
        case .attraction:
            query += " tourist attraction"
        default:
            break
        }

        return query
    }

    private func searchWikipedia(query: String) async throws -> [WikipediaSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        let urlString = "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=\(encodedQuery)&format=json&srlimit=3"

        guard let url = URL(string: urlString) else {
            throw EnrichmentError.invalidURL
        }

        let (data, _) = try await urlSession.data(from: url)
        let response = try JSONDecoder().decode(WikipediaSearchResponse.self, from: data)

        return response.query.search.map { result in
            WikipediaSearchResult(
                pageID: result.pageid,
                title: result.title,
                snippet: result.snippet
            )
        }
    }

    private func fetchWikipediaArticle(pageID: Int) async throws -> WikipediaArticle {
        let urlString = "https://en.wikipedia.org/w/api.php?action=query&pageids=\(pageID)&prop=extracts|info&exintro=1&explaintext=1&inprop=url&format=json"

        guard let url = URL(string: urlString) else {
            throw EnrichmentError.invalidURL
        }

        let (data, _) = try await urlSession.data(from: url)
        let response = try JSONDecoder().decode(WikipediaArticleResponse.self, from: data)

        guard let page = response.query.pages["\(pageID)"] else {
            throw EnrichmentError.articleNotFound
        }

        return WikipediaArticle(
            pageID: pageID,
            title: page.title,
            extract: page.extract ?? "No summary available.",
            url: page.fullurl ?? "https://en.wikipedia.org"
        )
    }

    // MARK: - Content Extraction

    private func extractFacts(from article: WikipediaArticle) -> [String] {
        // Extract sentences that contain years, numbers, or superlatives
        let sentences = article.extract.components(separatedBy: ". ")
        let factPatterns = [
            "\\d{4}", // Years
            "first", "largest", "oldest", "highest", "built", "founded"
        ]

        return sentences.filter { sentence in
            factPatterns.contains { pattern in
                sentence.range(of: pattern, options: .regularExpression) != nil
            }
        }.prefix(3).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func extractVisitTips(from article: WikipediaArticle) -> [String] {
        // Look for sentences about visiting, hours, access
        let sentences = article.extract.components(separatedBy: ". ")
        let tipPatterns = ["visit", "open", "hour", "access", "parking", "admission"]

        return sentences.filter { sentence in
            tipPatterns.contains { pattern in
                sentence.localizedCaseInsensitiveContains(pattern)
            }
        }.prefix(2).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func extractStories(from article: WikipediaArticle) -> [String] {
        // Extract narrative-style sentences
        let sentences = article.extract.components(separatedBy: ". ")

        // Look for sentences with narrative keywords
        let storyPatterns = ["legend", "story", "known for", "famous", "named after"]

        return sentences.filter { sentence in
            storyPatterns.contains { pattern in
                sentence.localizedCaseInsensitiveContains(pattern)
            }
        }.prefix(2).map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Wikipedia API Models

private struct WikipediaSearchResponse: Codable {
    let query: WikipediaSearchQuery
}

private struct WikipediaSearchQuery: Codable {
    let search: [WikipediaSearchItem]
}

private struct WikipediaSearchItem: Codable {
    let pageid: Int
    let title: String
    let snippet: String
}

private struct WikipediaSearchResult {
    let pageID: Int
    let title: String
    let snippet: String
}

private struct WikipediaArticleResponse: Codable {
    let query: WikipediaArticleQuery
}

private struct WikipediaArticleQuery: Codable {
    let pages: [String: WikipediaPage]
}

private struct WikipediaPage: Codable {
    let title: String
    let extract: String?
    let fullurl: String?
}

private struct WikipediaArticle {
    let pageID: Int
    let title: String
    let extract: String
    let url: String
}

// MARK: - In-Memory Cache

private actor EnrichmentCache {
    private var cache: [UUID: POIEnrichment] = [:]

    func get(poiID: UUID) -> POIEnrichment? {
        cache[poiID]
    }

    func set(poiID: UUID, enrichment: POIEnrichment) {
        cache[poiID] = enrichment
    }

    func clear() {
        cache.removeAll()
    }
}

// MARK: - Errors

public enum EnrichmentError: Error, LocalizedError {
    case invalidURL
    case articleNotFound
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Wikipedia URL"
        case .articleNotFound:
            return "Wikipedia article not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
