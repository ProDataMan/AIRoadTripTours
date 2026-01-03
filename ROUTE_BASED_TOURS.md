# Route-Based Audio Tours - Feature Design

## Overview

Transform the app from location-based POI discovery to intelligent route-based audio tours with rich, web-enriched content and interactive navigation.

## Core User Flows

### Flow 1: Multi-POI Tour Planning
**User story**: "I want to visit several interesting places and get the best route"

1. User discovers POIs near current location or search area
2. User selects 3-5 POIs of interest
3. System calculates optimal route visiting all selected POIs
4. System generates narration for each POI using web-enriched data
5. User starts tour with turn-by-turn navigation
6. At each POI: brief intro + option for detailed exploration

### Flow 2: Destination-Based Discovery
**User story**: "I'm driving from Portland to Seattle - entertain me along the way"

1. User enters origin and destination
2. System finds route using MapKit directions
3. System discovers POIs along the route (within X miles of path)
4. System segments route by POIs (every 30-60 minutes of driving)
5. For each segment:
   - Brief narration about upcoming POI
   - "Want to learn more?" prompt
   - If yes: detailed narration + optional navigation to POI
   - If no: continue to next segment

### Flow 3: Passive Entertainment Mode
**User story**: "Just tell me interesting things as I drive"

1. User starts navigation to destination
2. System monitors location in background
3. As user approaches POIs (within 2-5 miles):
   - Play 30-60 second narration about the POI
   - "This is [POI name]. [Interesting fact]. Want to visit?"
   - If yes: offer navigation detour
   - If no: continue route, mark as "mentioned"
4. Avoid repeating POIs on return trips

## Data Architecture

### Enhanced POI Model

```swift
public struct EnrichedPOI {
    let poi: POI
    let enrichment: POIEnrichment
    let routeContext: RouteContext?
}

public struct POIEnrichment {
    let webSummary: String          // From web search
    let historicalFacts: [String]    // Key facts
    let visitTips: [String]          // "Best time to visit", "Parking info"
    let interestingStories: [String] // Compelling narratives
    let sources: [URL]               // Attribution
    let enrichedAt: Date
}

public struct RouteContext {
    let distanceFromRoute: Double    // Miles off main route
    let detourDuration: TimeInterval // Extra time to visit
    let segmentIndex: Int            // Which route segment
    let estimatedArrival: Date       // When user will be nearby
}
```

### Route Planning Model

```swift
public struct AudioTourRoute {
    let id: UUID
    let origin: GeoLocation
    let destination: GeoLocation
    let waypoints: [GeoLocation]     // Intermediate stops
    let segments: [RouteSegment]
    let totalDistance: Double
    let estimatedDuration: TimeInterval
    let pois: [EnrichedPOI]
}

public struct RouteSegment {
    let id: UUID
    let startLocation: GeoLocation
    let endLocation: GeoLocation
    let distance: Double
    let duration: TimeInterval
    let poi: EnrichedPOI?            // Featured POI for this segment
    let nearbyPOIs: [EnrichedPOI]    // Alternative POIs
}
```

## Technical Implementation

### Phase 1: POI Enrichment Service

**File**: `Sources/AIRoadTripToursServices/POIEnrichmentService.swift`

```swift
import Foundation

/// Enriches POI data with web-sourced information
@available(iOS 17.0, macOS 14.0, *)
public actor POIEnrichmentService {

    /// Search the web for detailed information about a POI
    public func enrichPOI(_ poi: POI) async throws -> POIEnrichment {
        // Use Apple's web search or integration with search APIs
        // Priority:
        // 1. Wikipedia API (free, structured data)
        // 2. Apple News/Web search (if available)
        // 3. Cached enrichment data

        let searchQuery = buildSearchQuery(for: poi)
        let results = try await searchWeb(query: searchQuery)

        return POIEnrichment(
            webSummary: extractSummary(from: results),
            historicalFacts: extractFacts(from: results),
            visitTips: extractTips(from: results),
            interestingStories: extractStories(from: results),
            sources: results.map { $0.url },
            enrichedAt: Date()
        )
    }

    private func buildSearchQuery(for poi: POI) -> String {
        // Craft effective search queries
        "\(poi.name) \(poi.category.rawValue) history interesting facts"
    }
}
```

### Phase 2: Route Planning Service

**File**: `Sources/AIRoadTripToursServices/RoutePlanningService.swift`

```swift
import MapKit
import AIRoadTripToursCore

/// Plans optimal routes with POI integration
@available(iOS 17.0, macOS 14.0, *)
public actor RoutePlanningService {

    private let poiRepository: POIRepository
    private let enrichmentService: POIEnrichmentService

    /// Find POIs along a route between origin and destination
    public func findPOIsAlongRoute(
        origin: GeoLocation,
        destination: GeoLocation,
        maxDetourMiles: Double = 5.0,
        categories: Set<POICategory>? = nil
    ) async throws -> AudioTourRoute {

        // 1. Get route from MapKit
        let route = try await calculateRoute(from: origin, to: destination)

        // 2. Divide route into segments (every 30-60 min)
        let segments = divideIntoSegments(route: route)

        // 3. Find POIs near each segment
        var enrichedPOIs: [EnrichedPOI] = []

        for segment in segments {
            let nearbyPOIs = try await findPOIsNearSegment(
                segment: segment,
                route: route,
                maxDetourMiles: maxDetourMiles,
                categories: categories
            )

            // 4. Enrich POI data with web search
            for poi in nearbyPOIs {
                let enrichment = try await enrichmentService.enrichPOI(poi)
                let context = calculateRouteContext(poi: poi, segment: segment, route: route)
                enrichedPOIs.append(EnrichedPOI(
                    poi: poi,
                    enrichment: enrichment,
                    routeContext: context
                ))
            }
        }

        return AudioTourRoute(
            id: UUID(),
            origin: origin,
            destination: destination,
            waypoints: [],
            segments: segments,
            totalDistance: route.distance,
            estimatedDuration: route.expectedTravelTime,
            pois: enrichedPOIs
        )
    }

    /// Optimize route through multiple selected POIs
    public func optimizeMultiPOIRoute(
        startingAt origin: GeoLocation,
        visiting pois: [POI]
    ) async throws -> AudioTourRoute {

        // 1. Calculate all possible routes (TSP-like optimization)
        let optimizedOrder = optimizePOIOrder(from: origin, pois: pois)

        // 2. Build route with waypoints
        var waypoints = optimizedOrder.map { $0.location }

        // 3. Get turn-by-turn directions
        let route = try await calculateMultiStopRoute(
            origin: origin,
            waypoints: waypoints
        )

        // 4. Enrich each POI
        let enrichedPOIs = try await enrichPOIs(optimizedOrder)

        return AudioTourRoute(
            id: UUID(),
            origin: origin,
            destination: waypoints.last ?? origin,
            waypoints: waypoints,
            segments: createSegments(from: route, pois: enrichedPOIs),
            totalDistance: route.distance,
            estimatedDuration: route.expectedTravelTime,
            pois: enrichedPOIs
        )
    }

    private func calculateRoute(
        from origin: GeoLocation,
        to destination: GeoLocation
    ) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(
                latitude: origin.latitude,
                longitude: origin.longitude
            )
        ))
        request.destination = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(
                latitude: destination.latitude,
                longitude: destination.longitude
            )
        ))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw RoutePlanningError.noRouteFound
        }

        return route
    }

    private func divideIntoSegments(route: MKRoute) -> [RouteSegment] {
        // Divide route into ~30 minute segments
        let targetSegmentDuration: TimeInterval = 1800 // 30 minutes
        // Implementation details...
        []
    }

    private func findPOIsNearSegment(
        segment: RouteSegment,
        route: MKRoute,
        maxDetourMiles: Double,
        categories: Set<POICategory>?
    ) async throws -> [POI] {
        // Search for POIs within maxDetourMiles of segment path
        // Implementation details...
        []
    }
}

public enum RoutePlanningError: Error, LocalizedError {
    case noRouteFound
    case invalidWaypoints

    public var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "Could not find a route to destination"
        case .invalidWaypoints:
            return "Invalid waypoints provided"
        }
    }
}
```

### Phase 3: Enhanced Narration Generation

**File**: `Sources/AIRoadTripToursServices/EnrichedContentGenerator.swift`

```swift
import AIRoadTripToursCore

/// Generates narrations using enriched POI data
public actor EnrichedContentGenerator: ContentGenerator {

    private let enrichmentService: POIEnrichmentService

    public init(enrichmentService: POIEnrichmentService) {
        self.enrichmentService = enrichmentService
    }

    public func generateNarration(
        for poi: POI,
        targetDurationSeconds: Double,
        userInterests: Set<UserInterest>
    ) async throws -> Narration {

        // 1. Enrich POI with web data
        let enrichment = try await enrichmentService.enrichPOI(poi)

        // 2. Generate compelling narration from enriched data
        let content = buildNarrationContent(
            poi: poi,
            enrichment: enrichment,
            targetDuration: targetDurationSeconds,
            interests: userInterests
        )

        return Narration(
            id: UUID(),
            poiID: poi.id,
            poiName: poi.name,
            title: "Discovering \(poi.name)",
            content: content,
            style: .storytelling,
            targetAudience: .general,
            durationSeconds: targetDurationSeconds,
            interests: userInterests
        )
    }

    /// Generate a brief "teaser" narration for passive discovery
    public func generateTeaserNarration(
        for enrichedPOI: EnrichedPOI
    ) async throws -> Narration {

        let content = """
        Coming up on your route: \(enrichedPOI.poi.name).
        \(enrichedPOI.enrichment.historicalFacts.first ?? "An interesting place worth exploring.")
        Would you like to hear more?
        """

        return Narration(
            id: UUID(),
            poiID: enrichedPOI.poi.id,
            poiName: enrichedPOI.poi.name,
            title: "Teaser: \(enrichedPOI.poi.name)",
            content: content,
            style: .informative,
            targetAudience: .general,
            durationSeconds: 30.0,
            interests: []
        )
    }

    private func buildNarrationContent(
        poi: POI,
        enrichment: POIEnrichment,
        targetDuration: Double,
        interests: Set<UserInterest>
    ) -> String {
        // Craft engaging narration from enriched data
        // Prioritize content based on user interests
        // Target word count: ~150 words per minute of narration

        var content = enrichment.webSummary

        if !enrichment.historicalFacts.isEmpty {
            content += "\n\n" + enrichment.historicalFacts.joined(separator: " ")
        }

        if !enrichment.interestingStories.isEmpty {
            content += "\n\n" + enrichment.interestingStories.first!
        }

        return content
    }
}
```

### Phase 4: UI for Route Planning

**File**: `Sources/AIRoadTripToursApp/RoutePlannerView.swift`

```swift
import SwiftUI
import MapKit
import AIRoadTripToursCore
import AIRoadTripToursServices

public struct RoutePlannerView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var locationService = LocationService()

    @State private var planningMode: PlanningMode = .multiPOI
    @State private var origin: String = ""
    @State private var destination: String = ""
    @State private var selectedPOIs: Set<POI> = []
    @State private var plannedRoute: AudioTourRoute?
    @State private var isPlanning = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Mode selector
                Picker("Planning Mode", selection: $planningMode) {
                    Text("Multi-Stop Tour").tag(PlanningMode.multiPOI)
                    Text("Route Discovery").tag(PlanningMode.routeBased)
                }
                .pickerStyle(.segmented)
                .padding()

                if planningMode == .multiPOI {
                    multiPOIView
                } else {
                    routeBasedView
                }

                if let route = plannedRoute {
                    routePreview(route)
                }

                Spacer()
            }
            .navigationTitle("Plan Your Tour")
        }
    }

    private var multiPOIView: some View {
        VStack(spacing: 16) {
            Text("Select POIs to visit")
                .font(.headline)

            // POI selection list (reuse from DiscoverView)
            // Show selected count
            Text("\(selectedPOIs.count) POIs selected")
                .foregroundStyle(.secondary)

            Button {
                Task { await planMultiPOIRoute() }
            } label: {
                Label("Plan Optimal Route", systemImage: "map")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .disabled(selectedPOIs.count < 2)
            .padding(.horizontal)
        }
    }

    private var routeBasedView: some View {
        VStack(spacing: 16) {
            TextField("Starting location", text: $origin)
                .textFieldStyle(.roundedBorder)

            TextField("Destination", text: $destination)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await planRouteTour() }
            } label: {
                Label("Find POIs Along Route", systemImage: "map.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .disabled(destination.isEmpty)
            .padding(.horizontal)
        }
        .padding()
    }

    private func routePreview(_ route: AudioTourRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Route")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("\(Int(route.totalDistance)) miles")
                    Text("\(formatDuration(route.estimatedDuration))")
                }

                Spacer()

                Text("\(route.pois.count) POIs")
                    .font(.title2)
                    .bold()
            }

            Button {
                // Start tour
            } label: {
                Label("Start Audio Tour", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
        .padding()
    }

    private func planMultiPOIRoute() async {
        // Implementation
    }

    private func planRouteTour() async {
        // Implementation
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
}

enum PlanningMode {
    case multiPOI
    case routeBased
}
```

## Implementation Phases

### Phase 1: POI Enrichment (Week 1)
- [ ] Implement Wikipedia API integration
- [ ] Create POIEnrichmentService
- [ ] Cache enrichment data locally
- [ ] Test enrichment quality

### Phase 2: Route Planning (Week 2)
- [ ] Implement RoutePlanningService
- [ ] MapKit directions integration
- [ ] Multi-waypoint optimization
- [ ] POI-to-route proximity calculation

### Phase 3: Enhanced Narration (Week 3)
- [ ] Update ContentGenerator with enriched data
- [ ] Generate teaser vs detailed narrations
- [ ] Test narration quality and timing

### Phase 4: UI Implementation (Week 4)
- [ ] RoutePlannerView
- [ ] RoutePreviewView with map
- [ ] Interactive POI selection
- [ ] Turn-by-turn integration

### Phase 5: Passive Discovery (Week 5)
- [ ] Background location monitoring
- [ ] Proximity-based narration triggers
- [ ] "Want to learn more?" prompts
- [ ] Detour navigation

## Data Sources for POI Enrichment

### Primary Sources (Free)
1. **Wikipedia API**: Structured historical/factual data
2. **Wikidata**: Related facts, connections
3. **OpenStreetMap**: Additional location context

### Secondary Sources (Requires API Keys)
1. **Yelp Fusion API**: Reviews, tips, photos
2. **Google Places API**: Reviews, ratings, photos
3. **Apple News API**: Recent articles (if available)

### Fallback
- Cached enrichment database
- Community-contributed content

## Privacy & Performance Considerations

1. **Caching**: Cache enriched POI data for 30 days
2. **Background refresh**: Update enrichment data opportunistically
3. **Offline mode**: Gracefully degrade to basic POI info
4. **Attribution**: Always cite sources in "About this POI" section
5. **User control**: Allow users to skip web enrichment for privacy

## Success Metrics

1. **Engagement**: % of users who complete route-based tours
2. **Detour rate**: % of offered POI detours accepted
3. **Narration quality**: User ratings on narration helpfulness
4. **Route completion**: % of planned routes fully executed

---

**Next Steps**: Implement Phase 1 (POI Enrichment) with Wikipedia API integration.
