# Interactive Audio Tour with Voice Control - Design Document

## User Experience Flow

### Phase 1: Approaching POI (3-5 minutes away)

**Trigger**: User's location is within 3-5 minutes driving time to next POI

**Audio**: Brief teaser (30 seconds)
```
"Coming up in about 4 minutes: Multnomah Falls.
Oregon's tallest waterfall at 620 feet, it's one of the most
photographed natural wonders in the Pacific Northwest.
Would you like to hear more?"
```

**Display**:
- POI thumbnail image
- Distance/time to POI
- "Listening..." indicator during speech recognition

**User Response**:
- **"Yes" / "Sure" / "Tell me more"** → Phase 2
- **"No" / "Skip"** → Mark as mentioned, continue to next POI
- **No response (5 seconds)** → Assume no, continue

---

### Phase 2: Detailed Narration (1-2 minutes away)

**Audio**: Full Wikipedia-enriched narration (90-120 seconds)
```
"Multnomah Falls is a stunning two-tiered waterfall on the Oregon
side of the Columbia River Gorge. The upper falls drop 542 feet
while the lower falls drop 69 feet, giving a total height of 620 feet.

The falls were named after a Multnomah chief in a Native American
legend. According to the story, a young maiden sacrificed herself
by jumping from the top of the waterfall to appease the gods and
stop a plague affecting her tribe.

The iconic Benson Bridge spans the lower falls, offering visitors
an up-close view of this natural wonder. Built in 1914, it's named
after businessman Simon Benson who donated the land.

Fun fact: Multnomah Falls is the most visited natural recreation
site in the Pacific Northwest, attracting over 2 million visitors
annually..."
```

**Display**:
- Slideshow: 5-10 POI images rotating every 10-15 seconds
- Progress bar showing narration completion
- Current narration section highlight

---

### Phase 3: Arrival Prompt (< 1 minute away)

**Trigger**: User is within 0.5 miles or 1 minute of POI

**Audio**: Guided tour offer
```
"We're approaching Multnomah Falls now. Would you like to stop
for a guided tour? I can provide detailed information as you
explore the area, including the hiking trail to the top, the
visitor center, and the best photo spots."
```

**User Response**:
- **"Yes"** → Enter Guided Tour Mode
- **"No"** → Continue to next POI, mark as "passed"

---

### Phase 4: Guided Tour Mode (Optional)

**Trigger**: User said "yes" and vehicle has stopped/slowed significantly

**Features**:
- Turn-by-turn navigation to parking
- On-site POI details:
  - "You're at the base of the falls. Look up to see..."
  - "The trail to the top is on your right..."
  - "The best photo spot is from Benson Bridge..."
- Points of interest within the POI
- Historical anecdotes and stories
- Practical tips (restrooms, accessibility, etc.)

**Display**:
- Interactive map of POI area
- Points of interest markers
- Current location indicator
- Photo spot suggestions

---

## Technical Architecture

### 1. Narration State Machine

```swift
enum NarrationPhase {
    case approaching    // 3-5 min away: teaser
    case detailed       // 1-2 min away: full narration
    case arrival        // <1 min away: guided tour offer
    case guidedTour     // On-site: detailed exploration
    case passed         // User passed POI without stopping
}

enum UserResponse {
    case yes
    case no
    case noResponse
}
```

### 2. Proximity Monitoring

```swift
actor ProximityMonitor {
    func estimatedTimeToArrival(
        from: GeoLocation,
        to: POI,
        currentSpeed: Double
    ) -> TimeInterval

    func shouldTriggerTeaser(distance: Double, eta: TimeInterval) -> Bool
    func shouldTriggerDetailed(distance: Double, eta: TimeInterval) -> Bool
    func shouldTriggerArrival(distance: Double, eta: TimeInterval) -> Bool
}
```

### 3. Speech Recognition

```swift
actor VoiceInteractionService {
    func listenForResponse(
        expecting: Set<String>,
        timeout: TimeInterval
    ) async -> UserResponse

    // Recognizes: "yes", "sure", "okay", "tell me more", etc.
    // Also: "no", "skip", "next", "not interested", etc.
}
```

### 4. Image Service

```swift
actor POIImageService {
    func fetchImages(for poi: POI) async throws -> [POIImage]

    // Sources:
    // 1. Wikipedia Commons API
    // 2. Unsplash API (for high-quality photos)
    // 3. Cached local images
}

struct POIImage {
    let url: URL
    let thumbnail: URL
    let caption: String?
    let attribution: String
}
```

### 5. Navigation Simulator

```swift
actor NavigationSimulator {
    var currentLocation: GeoLocation
    var currentSpeed: Double // mph
    var isSimulating: Bool

    func startSimulation(route: [POI])
    func updateLocation() // Called every second
    func stop()
}
```

---

## Implementation Plan

### Phase 1: Proximity-Based Triggers ✅ Start Here

**Files to Create**:
1. `ProximityMonitor.swift` - Distance/ETA calculation
2. `NarrationStateMachine.swift` - Phase transitions
3. `NavigationSimulator.swift` - Mock location updates for testing

**Files to Modify**:
1. `AudioTourView.swift` - Add proximity monitoring
2. `LocationService.swift` - Add speed/heading tracking
3. `EnrichedContentGenerator.swift` - Add teaser vs detailed generation

### Phase 2: Voice Interaction

**Files to Create**:
1. `VoiceInteractionService.swift` - Speech recognition wrapper
2. `VoicePrompts.swift` - Predefined voice prompts

**Dependencies**:
- `import Speech` (iOS built-in)
- Request microphone permission

### Phase 3: Image Integration

**Files to Create**:
1. `POIImageService.swift` - Fetch from Wikipedia/Unsplash
2. `POIImageCache.swift` - Local image caching
3. `ImageSlideshowView.swift` - SwiftUI slideshow component

**APIs**:
- Wikipedia Commons API (free)
- Unsplash API (free tier: 50 requests/hour)

### Phase 4: Enhanced UI

**Files to Create**:
1. `ActiveTourView.swift` - Full-screen narration + slideshow
2. `GuidedTourView.swift` - On-site tour interface
3. `ProximityIndicatorView.swift` - Distance/ETA display

---

## Testing Strategy

### Development Mode Features

1. **Navigation Simulator Toggle**
```swift
@State private var useSimulatedNavigation = true
```

2. **Speed Controls**
```swift
// Adjustable simulation speed
@State private var simulationSpeed: Double = 1.0 // 1x = real-time
// Options: 0.5x, 1x, 2x, 5x, 10x
```

3. **Location Scrubber**
```swift
// Slider to manually position along route
Slider(value: $routeProgress, in: 0...1)
// Shows: "42% to destination, approaching POI 2"
```

4. **Phase Override**
```swift
// Manual phase triggers for testing
Button("Force Teaser") { stateMachine.forcePhase(.approaching) }
Button("Force Detailed") { stateMachine.forcePhase(.detailed) }
Button("Force Arrival") { stateMachine.forcePhase(.arrival) }
```

### Test Scenarios

**Scenario 1: Happy Path**
1. Start tour with 3 selected POIs
2. Simulator moves toward POI 1 at 45 mph
3. At 4 min away: Teaser plays, user says "yes"
4. At 1.5 min away: Detailed narration plays
5. At 0.5 min away: Guided tour offer, user says "yes"
6. Simulator stops, guided tour begins
7. User explores for 5 minutes
8. User says "continue tour"
9. Repeat for POI 2, 3

**Scenario 2: Skip Path**
1. Teaser plays, user says "no"
2. Skip to next POI
3. Mark POI as "mentioned but skipped"

**Scenario 3: Passive Path**
1. Teaser plays, no response
2. Wait 5 seconds
3. Assume "no", continue to next POI

---

## Voice Recognition Patterns

### Affirmative Responses
- "yes", "yeah", "yep", "sure"
- "okay", "ok", "alright"
- "tell me more", "continue", "go ahead"
- "I'd like to hear more"
- "sounds interesting"

### Negative Responses
- "no", "nope", "nah"
- "skip", "next", "pass"
- "not interested", "no thanks"
- "maybe later"

### Guided Tour Responses
- "yes, let's stop"
- "I want to tour it"
- "let's explore"
- "no, keep going"
- "continue the route"

---

## Image Slideshow Design

### Layout
```
┌─────────────────────────────────┐
│                                 │
│         POI Image (Full)        │  ← Auto-rotating slideshow
│                                 │
├─────────────────────────────────┤
│  "Multnomah Falls, Oregon"      │  ← Caption
│  Photo: John Smith (CC-BY)      │  ← Attribution
├─────────────────────────────────┤
│  🔊 [====>      ] 0:32 / 1:45  │  ← Audio progress
├─────────────────────────────────┤
│  📍 3.2 miles • ~4 min away     │  ← Distance/ETA
└─────────────────────────────────┘
```

### Image Timing
- 1 image per 10-15 seconds of narration
- Smooth fade transitions (0.5s)
- Pause slideshow during voice prompts
- Resume after user response

---

## Production Considerations

### Privacy
- Request microphone permission with clear explanation
- Allow users to disable voice interaction (use buttons instead)
- Don't record or store voice data

### Performance
- Preload images for next 2 POIs
- Cache Wikipedia images locally
- Limit to 5-10 images per POI
- Use thumbnail images for list view

### Offline Mode
- Cache narrations and images when online
- Graceful degradation: text-only mode if no images
- Button fallback if voice recognition unavailable

### Accessibility
- VoiceOver compatible
- Large touch targets for buttons
- High contrast mode support
- Text captions for all audio

---

## API Integration

### Wikipedia Commons API

**Search for images**:
```
https://commons.wikimedia.org/w/api.php?
  action=query&
  generator=search&
  gsrsearch=Multnomah+Falls&
  gsrnamespace=6&
  gsrlimit=10&
  prop=imageinfo&
  iiprop=url|extmetadata
```

**Response**: URLs to images with metadata

### Speech Recognition (iOS Native)

```swift
import Speech

let recognizer = SFSpeechRecognizer()
let request = SFSpeechAudioBufferRecognitionRequest()

recognizer?.recognitionTask(with: request) { result, error in
    if let transcription = result?.bestTranscription.formattedString {
        // Process: "yes", "no", etc.
    }
}
```

---

## Next Steps

1. ✅ Implement ProximityMonitor
2. ✅ Implement NavigationSimulator
3. ✅ Update EnrichedContentGenerator for teaser/detailed split
4. ✅ Implement NarrationStateMachine
5. Create VoiceInteractionService
6. Create POIImageService
7. Build ActiveTourView with slideshow
8. Add simulator controls to AudioTourView

**Start with**: ProximityMonitor and NavigationSimulator for testable foundation.
