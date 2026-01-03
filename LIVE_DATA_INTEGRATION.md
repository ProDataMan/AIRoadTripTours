# Live Data Integration

## Overview

The AI Road Trip Tours app now uses **live data sources** instead of static data:

1. **POI Discovery**: MapKit `MKLocalSearch` for real-time Apple Maps data
2. **Narration**: Ready for Apple Intelligence integration (iOS 18.1+)

## MapKit POI Discovery

### Implementation

**File**: `Sources/AIRoadTripToursServices/MapKitPOIService.swift`

The `MapKitPOIService` actor provides live POI data from Apple Maps:

```swift
@available(iOS 17.0, macOS 14.0, *)
public actor MapKitPOIService: POIRepository {
    public func findNearby(
        location: GeoLocation,
        radiusMiles: Double,
        categories: Set<POICategory>?
    ) async throws -> [POI]
}
```

### How It Works

1. **Location-based search**: Uses `MKLocalSearch.Request` with natural language queries
2. **Category mapping**: Converts app categories to MapKit search terms
   - `restaurant` → "restaurant"
   - `cafe` → "cafe coffee"
   - `attraction` → "tourist attraction"
   - `waterfall` → "waterfall"
   - `evCharger` → "electric vehicle charging station"
3. **Radius filtering**: Searches within specified mile radius
4. **Deduplication**: Removes duplicate results within 50 meters

### Data Returned

MapKit provides:
- ✅ POI name
- ✅ Geographic coordinates
- ✅ Address (formatted)
- ✅ Phone number
- ✅ Website URL
- ❌ No ratings (use Yelp/Google Places API for ratings)
- ❌ No descriptions (generate with Apple Intelligence)

## Apple Intelligence for Narration

### Status: Ready for Integration (iOS 18.1+)

Apple Intelligence APIs can generate contextual narrations on-device:

### Planned Implementation

**File**: `Sources/AIRoadTripToursServices/AppleIntelligenceNarrationService.swift` (to be created)

```swift
import AppleIntelligence  // iOS 18.1+

@available(iOS 18.1, *)
public actor AppleIntelligenceNarrationService: ContentGenerator {

    public func generateNarration(
        for poi: POI,
        targetDurationSeconds: Double,
        userInterests: Set<UserInterest>
    ) async throws -> Narration {

        // Use Apple Intelligence to generate contextual narration
        let prompt = buildNarrationPrompt(poi: poi, interests: userInterests)

        let intelligence = AIIntelligence.shared
        let response = try await intelligence.generateText(
            prompt: prompt,
            maxTokens: Int(targetDurationSeconds * 3), // ~3 words per second
            temperature: 0.7
        )

        return Narration(
            id: UUID(),
            poiID: poi.id,
            poiName: poi.name,
            title: "About \(poi.name)",
            content: response.text,
            style: .informative,
            targetAudience: .general,
            durationSeconds: targetDurationSeconds,
            interests: userInterests
        )
    }

    private func buildNarrationPrompt(poi: POI, interests: Set<UserInterest>) -> String {
        var prompt = """
        Generate a \(Int(targetDurationSeconds))-second narration for \(poi.name),
        a \(poi.category.rawValue) located at \(poi.location.address ?? "this location").
        """

        if !interests.isEmpty {
            let interestList = interests.map { $0.name }.joined(separator: ", ")
            prompt += "\n\nTailor the narration to someone interested in: \(interestList)."
        }

        if let description = poi.description {
            prompt += "\n\nBackground: \(description)"
        }

        prompt += "\n\nMake it engaging and informative for a road trip traveler."

        return prompt
    }
}
```

### Current Fallback

Until Apple Intelligence is available, the app uses:
- `MockContentGenerator`: Generates template-based narrations
- `AVSpeechNarrationAudioService`: Text-to-speech for audio playback

### Integration Steps (When Available)

1. **Check availability**:
   ```swift
   if #available(iOS 18.1, *), AIIntelligence.isAvailable {
       self.contentGenerator = AppleIntelligenceNarrationService()
   } else {
       self.contentGenerator = MockContentGenerator()
   }
   ```

2. **Update AppState**:
   ```swift
   public let contentGenerator: ContentGenerator
   ```

3. **Privacy**: Add usage description to Info.plist
   ```xml
   <key>NSAppleIntelligenceUsageDescription</key>
   <string>Generate personalized tour narrations based on your interests</string>
   ```

## Benefits of Live Data Approach

### POI Discovery (MapKit)
- ✅ Always up-to-date location data
- ✅ No backend required
- ✅ Works offline (cached maps)
- ✅ Respects user privacy (Apple handles data)
- ✅ Free (included with Apple Maps)

### Narration (Apple Intelligence)
- ✅ On-device processing (private)
- ✅ No API costs
- ✅ Works offline
- ✅ Personalized to user interests
- ✅ Consistent with Apple ecosystem

## Testing Live MapKit Data

**In Xcode**: Press **⌘R** to rebuild and run the app.

**Test steps**:
1. Complete onboarding
2. Go to **Discover** tab
3. Tap "Search Nearby POIs"
4. App searches Apple Maps for real POIs near Portland, OR
5. Results include restaurants, cafes, attractions, parks, museums, and more
6. Tap any POI to see details with live address data

**Expected behavior**:
- Search takes 1-3 seconds (network call to Apple Maps)
- Returns 10-50 POIs depending on density
- Each POI has name, location, and optionally phone/website
- No ratings displayed (MapKit limitation)

## Future Enhancements

1. **User location**: Request location permission and search near user's current location
2. **Category filtering**: Allow user to filter by specific categories
3. **Ratings integration**: Add Yelp Fusion API for ratings and reviews
4. **Photos**: Integrate Yelp/Google Places for POI photos
5. **Apple Intelligence**: Generate rich narrations when iOS 18.1+ becomes available

---

**Status**: ✅ Live MapKit integration complete
**Next**: Wait for Apple Intelligence APIs in iOS 18.1+
**Last Updated**: December 16, 2025
