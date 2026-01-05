# Session Continuation - Map Zoom During POI Introduction Fix

## Status: COMPLETE ✅ - Committed and Pushed

### Latest Changes (2026-01-05)
1. ✅ **NotificationCenter Solution** - Committed (d1d556d) and pushed
   - Implements workaround for SwiftUI @Observable observation limitation across sheet boundaries
   - Map now zooms correctly when POIs are introduced during narration
   - Yellow highlight circle appears/moves dynamically with narration

2. ✅ **Tighter Zoom Level** - Committed (c82c855) and pushed
   - Reduced zoom from 0.02° to 0.003° (6.7x tighter)
   - Provides very tight street-level view showing POI within ~half a block
   - Located in TourMapView.swift line 266

## Previous Status: Build SUCCESSFUL - NotificationCenter Solution Implemented

## Final Solution: NotificationCenter (Workaround for SwiftUI Limitation)

### Root Cause Confirmed
After extensive testing with multiple approaches:
1. ❌ @Bindable parameter passing
2. ❌ @Environment access
3. ❌ Direct value reading in body
4. ❌ @State intermediate tracking with .onChange

**All failed** because @Observable observation is fundamentally broken across sheet presentation boundaries in SwiftUI.

### The Solution: NotificationCenter

Bypassed SwiftUI's observation system entirely using NotificationCenter:

**AudioTourManager.swift (lines 64-74)**:
```swift
public var introducingPOIIndex: Int? = nil {
    didSet {
        print("🗺️ AudioTourManager: introducingPOIIndex changed...")
        // Post notification to communicate across sheet boundary
        NotificationCenter.default.post(
            name: NSNotification.Name("IntroducingPOIIndexChanged"),
            object: nil,
            userInfo: ["index": introducingPOIIndex as Any]
        )
    }
}
```

**MapSheetView (AudioTourView.swift:856-899)**:
```swift
@State private var introducingPOIIndex: Int? = nil

var body: some View {
    NavigationStack {
        TourMapView(
            introducingPOIIndex: introducingPOIIndex,  // Pass @State value
            ...
        )
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("IntroducingPOIIndexChanged"))) { notification in
        // Update @State from notification
        if let index = notification.userInfo?["index"] as? Int {
            introducingPOIIndex = index
        } else {
            introducingPOIIndex = nil
        }
    }
}
```

### How It Works

1. AudioTourManager sets `introducingPOIIndex = 0`
2. `didSet` posts NotificationCenter notification
3. MapSheetView receives notification via `.onReceive`
4. Updates `@State var introducingPOIIndex`
5. SwiftUI triggers body re-render
6. TourMapView receives new value as parameter
7. TourMapView's `.onChange` fires and zooms map

### Expected Console Output

```
🗺️ AudioTourManager: introducingPOIIndex changed from nil to Optional(0)
🗺️ MapSheetView: Received notification
🗺️ MapSheetView: Updating introducingPOIIndex to 0
🗺️ 🚨 MapSheetView.body RENDERING: ... introducing=Optional(0)  ← Should appear!
🗺️ Map.onChange: introducingPOIIndex changed from nil to Optional(0)
🗺️ zoomToIntroducingPOI(0): Zooming to Patty's Eggnest
```

### Build Status
✅ Build complete! (5.99s)
✅ Only unrelated warnings
✅ Ready for testing

## Expected Behavior When Testing

1. **Start Tour**: Click "Start Tour" button in Audio Tour tab
2. **Map Opens**: Map sheet opens immediately showing all POIs
3. **NO Yellow Circle Initially**: No POI should have a yellow highlight circle when map first appears
4. **Welcome Narration**: "Welcome to AI Road Trip Tours..." plays
5. **Tour Overview**: "Today's tour includes N fascinating destinations..."
6. **First POI Introduction**:
   - Narration: "Stop number 1: [POI Name]..."
   - Map: **Yellow circle appears on POI 1**
   - Map: **Zooms in to street-level view** (0.02° span = ~1-2 blocks)
   - Console: `🗺️ Map.onChange: introducingPOIIndex changed from nil to Optional(0)`
   - Console: `🗺️ zoomToIntroducingPOI(0): Zooming to [POI Name]`
7. **After First POI**: Map zooms back out to show all POIs, yellow circle disappears
8. **Second POI Introduction**:
   - Narration: "Stop number 2: [POI Name]..."
   - Map: **Yellow circle moves to POI 2**
   - Map: **Zooms in to POI 2**
9. **Pattern Repeats**: For each POI, yellow circle moves and map zooms

## Latest Fix Applied: Changed TourMapView to use @Bindable var tourManager

### Change Made
TourMapView.swift line 17: Changed from `let tourManager: AudioTourManager` to `@Bindable var tourManager: AudioTourManager`

This enables SwiftUI's observation system to properly track changes to `tourManager.introducingPOIIndex`, which should make:
1. The `.onChange(of: tourManager.introducingPOIIndex)` handler fire properly (lines 181-198)
2. The body re-render when introducingPOIIndex changes
3. The annotationsWithHighlight function receive the updated value

Build Status: ✅ Build complete! (5.83s)

## Previous Issue: Map Not Zooming to Individual POIs During Introduction

### Problem
Map wasn't zooming to individual POIs when each was mentioned during the welcome introduction narration, even though AudioTourManager was correctly setting introducingPOIIndex.

### Console Evidence
AudioTourManager was working correctly:
```
🗺️ AudioTourManager: introducingPOIIndex changed from nil to Optional(0)
🎯 Zooming to POI 0: Patty's Eggnest
```

But TourMapView's onChange handler never fired - no corresponding logs appeared.

### Root Cause
TourMapView was receiving `introducingPOIIndex` as a `let` parameter passed from MapSheetView:
```swift
// OLD - Parameter-based approach (broken)
public struct TourMapView: View {
    let introducingPOIIndex: Int?

    .onChange(of: introducingPOIIndex) { ... }  // Never fires - value is snapshot
}
```

This meant TourMapView had a snapshot of the value when created, but couldn't observe subsequent updates.

### Solution
Changed TourMapView to observe AudioTourManager directly using @Bindable:

**TourMapView.swift Changes:**
```swift
// NEW - Direct observation (fixed)
public struct TourMapView: View {
    @Bindable var tourManager: AudioTourManager

    public init(
        tourManager: AudioTourManager,
        ...
    ) {
        self.tourManager = tourManager
    }

    // Now observes the manager's property directly
    .onChange(of: tourManager.introducingPOIIndex) { oldValue, newValue in
        if let index = newValue, index < pois.count {
            zoomToIntroducingPOI(index: index)
        } else if oldValue != nil && newValue == nil {
            fitAllPOIs()
        }
    }
}
```

**AudioTourView.swift Changes (MapSheetView):**
```swift
// Removed intermediate read
var body: some View {
    let currentIndex = tourManager.currentSessionIndex
    // Removed: let introducingIndex = tourManager.introducingPOIIndex

    TourMapView(
        pois: pois,
        sessions: sessions,
        tourManager: tourManager,  // Pass manager instead of property value
        currentSessionIndex: currentIndex,
        currentLocation: currentLocation
    )
}
```

### Files Modified in This Session Segment

1. **TourMapView.swift**
   - Lines 10-52: Changed to accept and observe `@Bindable var tourManager`
   - Line 211: Updated task to read `tourManager.introducingPOIIndex`
   - Lines 178-195: Updated onChange to observe `tourManager.introducingPOIIndex`
   - Lines 797-831: Updated preview to create and pass tourManager

2. **AudioTourView.swift (MapSheetView)**
   - Lines 855-869: Removed intermediate introducingIndex read, pass tourManager directly to TourMapView

### Expected Behavior After Fix

When running the app and starting a tour:

1. Map opens immediately with all POIs visible
2. Welcome narration begins: "Welcome to AI Road Trip Tours..."
3. Tour overview plays: "Today's tour includes N fascinating destinations..."
4. **For each POI introduction**:
   - Narration says: "Stop number 1: [POI Name]..."
   - **Map should zoom in to street-level view of that POI**
   - Console shows: `🗺️ Map.onChange: introducingPOIIndex changed from nil to Optional(0)`
   - Console shows: `🗺️ zoomToIntroducingPOI(0): Zooming to [POI Name] at (lat, lon)`
   - After POI narration completes, map zooms back out to full view
5. Repeat zoom in/out for each POI
6. Final message: "That's your tour preview! Now, let's begin..."

### Testing Instructions

**Test: Map Zooms to Each POI During Introduction**
1. Open app in simulator
2. Go to Discover tab
3. Add 2-3 POIs using + button
4. Go to Audio Tour tab
5. Click **Start Tour**
6. Watch map during narration

**Expected Console Output:**
```
🗺️ About to introduce 3 POIs individually
🗺️ AudioTourManager: introducingPOIIndex changed from nil to Optional(0)
🎯 Zooming to POI 0: First POI Name
🗺️ Map.onChange: introducingPOIIndex changed from nil to Optional(0)
🗺️ zoomToIntroducingPOI(0): Zooming to First POI Name at (45.xxx, -122.xxx)
🗺️ Region updated to: center=(45.xxx, -122.xxx), span=(0.02, 0.02)
(narration plays for first POI)
🗺️ AudioTourManager: introducingPOIIndex changed from Optional(0) to nil
🗺️ Map.onChange: introducingPOIIndex changed from Optional(0) to nil
🗺️ Zooming back out to full view
🗺️ AudioTourManager: introducingPOIIndex changed from nil to Optional(1)
🎯 Zooming to POI 1: Second POI Name
🗺️ Map.onChange: introducingPOIIndex changed from nil to Optional(1)
...
```

**Expected Visual Behavior:**
- Map starts zoomed out to show all POIs
- When first POI is introduced, map **smoothly animates zoom in** to that location
- Zoom level: 0.02° latitude/longitude delta (approximately 1-2 city blocks)
- After first POI narration, map **zooms back out** to show all POIs
- Repeats zoom in/out for each POI introduction
- All animations should be smooth with 1.5 second duration

**Success Criteria:**
✅ Map automatically zooms to each POI when mentioned in narration
✅ Console shows onChange handler firing for introducingPOIIndex changes
✅ Zoom level is close enough to see street detail (0.02° delta)
✅ Map returns to full view between POI introductions

## Build Status

```bash
swift build
```

Output:
```
Build complete! (5.92s)
```

✅ No compilation errors
✅ Only unrelated warnings about unused variables in AudioTourManager.swift
✅ Ready for testing

## Current Session Work

### Issue: Map Not Appearing During Tour Introduction

**Problem**: Map sheet wasn't displaying at all, or when it did appear, the narration had already finished.

**Root Cause Analysis**:

1. **First Issue**: SwiftUI @Observable observation doesn't propagate across sheet boundaries
   - MapSheetView observing `tourManager.currentPOIs` read 0 even when manager had 2 POIs
   - Solution: Explicit parameter passing (snapshot pattern)

2. **Second Issue**: Map opened before POIs were loaded
   - Initial code opened map immediately, before `startTour()` set POIs
   - Solution: Moved `showMap = true` to after tour preparation

3. **Third Issue**: Excessive voice logging cluttering console
   - Voice selection logs repeated multiple times
   - Solution: Removed all print statements from VoiceConfiguration and NarrationAudio

4. **Fourth Issue**: Callback approach failed
   - Set callback in AudioTourView but showed as `nil` when manager invoked it
   - Root cause: Closures capturing `@State` from structs don't work in @Observable objects
   - Solution: Abandoned callback pattern

5. **CRITICAL ISSUE**: `startTour()` blocks for 30+ seconds during narration
   - Awaiting `startTour()` meant map only opened AFTER narration finished
   - This defeated the purpose of showing map during introduction
   - **Final Solution**: Split tour preparation from narration playback

## Final Implementation

### AudioTourManager.swift - Refactored Tour Methods

**New Architecture**:
```swift
// Prepare tour (returns immediately)
public func prepareTour(pois: [POI], userInterests: Set<UserInterest>) async {
    // Stop any existing tour
    // Set currentPOIs and sessions
    // Load images in parallel
    // Set isPrepared = true
    // Returns immediately - no narration
}

// Play welcome (separate method)
public func playWelcomeIntroduction() async {
    // Play welcome message
    // Introduce each POI with map zoom
    // Blocks until narration completes
}

// Convenience method (backward compatible)
public func startTour(pois: [POI], userInterests: Set<UserInterest>) async {
    await prepareTour(pois: pois, userInterests: userInterests)
    await playWelcomeIntroduction()
}
```

**Key Changes**:
- Lines 88-122: New `prepareTour()` method - sets up tour, returns immediately
- Lines 124-130: Refactored `startTour()` - calls both methods for backward compatibility
- Line 332: Made `playWelcomeIntroduction()` public with documentation

### AudioTourView.swift - New Flow

**Lines 474-501**:
```swift
print("🚀 Preparing tour with \(pois.count) POIs...")

// Prepare tour (sets POIs and sessions, returns immediately)
await tourManager.prepareTour(
    pois: pois,
    userInterests: appState.currentUser?.interests ?? []
)

// Tour is now prepared - capture snapshot for map
print("🗺️ 📸 Capturing snapshot after prepareTour returned")
mapPOIs = tourManager.currentPOIs
mapSessions = tourManager.sessions
print("🗺️ 📸 Snapshot captured: mapPOIs.count=\(mapPOIs.count), mapSessions.count=\(mapSessions.count)")

// Open map if we have POIs
if !mapPOIs.isEmpty {
    print("🗺️ 🚨 Opening map with \(mapPOIs.count) POIs")
    showMap = true
}

print("✅ Tour prepared successfully")

// Play welcome introduction in background (map is already visible)
print("🔊 Starting welcome introduction (background)")
Task {
    await tourManager.playWelcomeIntroduction()
    print("🔊 Welcome introduction completed")
}
```

**How It Works**:
1. Call `prepareTour()` - returns immediately after setting POIs/sessions
2. Capture snapshot of POIs/sessions from tourManager
3. Open map with snapshot data
4. Start welcome introduction in background Task
5. Map is visible WHILE narration plays
6. Map zooms to POIs as they are introduced

## Expected Console Output When Testing

```
🎯 Start Audio Tour button pressed
✅ Location available: 45.5152, -122.6784
🔍 Getting POIs...
📍 Using 2 selected POIs
🚀 Preparing tour with 2 POIs...
🗺️ AudioTourManager: currentPOIs changed from 0 to 2 POIs
🗺️ ✅ POIs and sessions ready for map display
✅ Tour prepared with 2 POIs
🗺️ 📸 Capturing snapshot after prepareTour returned
🗺️ 📸 Snapshot captured: mapPOIs.count=2, mapSessions.count=2
🗺️ 🚨 Opening map with 2 POIs
🗺️ showMap is now: true
✅ Tour prepared successfully
🔊 Starting welcome introduction (background)
🗺️ 🚨 SHEET PRESENTATION TRIGGERED - showMap=true, mapPOIs.count=2
🗺️ MapSheetView.body RENDERING: pois=2, sessions=2
🗺️ TourMapView.init() pois=2
🗺️ TourMapView.body: pois=2
🗺️ Map: POIs changed from 0 to 2
🗺️ fitAllPOIs() called
🗺️ annotations: Creating markers for 2 POIs
(Narration plays while map is visible)
🗺️ AudioTourManager: introducingPOIIndex changed to 0
🎯 Zooming to POI 0: First POI Name
(Map zooms to first POI)
🔊 Welcome introduction completed
```

## Architecture Evolution

### Attempt 1: Direct await (FAILED)
```
await startTour() → blocks for 30s → capture POIs → open map
Problem: Map opens after narration finishes
```

### Attempt 2: Background task + delay (FAILED)
```
Task { await startTour() } → sleep 200ms → capture POIs → open map
Problem: POIs not loaded yet (too fast)
```

### Attempt 3: Polling loop (FAILED)
```
while !poisReadyForMap { sleep 50ms }
Problem: @Observable doesn't wake loops
```

### Attempt 4: Callback (FAILED)
```
Set callback → await startTour() → callback invokes → open map
Problem: Callback was nil when invoked (closure capture issue)
```

### Attempt 5: Split preparation from narration (SUCCESS)
```
await prepareTour() → capture POIs → open map → Task { play narration }
Result: Map opens immediately, narration plays while visible
```

## Files Modified This Session

### VoiceConfiguration.swift
- Removed all print statements from `getBestVoice()` (lines 27-59)
- Removed print statement from `getRecommendedVoice()` (lines 78-86)

### NarrationAudio.swift
- Removed voice didSet observer with logging (lines 24-25)
- Removed initialization logging (lines 36-47)
- Removed all play() logging (lines 60-89)
- Removed audio session logging (lines 138-149)
- Removed speech synthesizer delegate logging (lines 205-230)

### AudioTourManager.swift
- Added `prepareTour()` method (lines 88-122) - returns immediately
- Refactored `startTour()` as convenience method (lines 124-130)
- Made `playWelcomeIntroduction()` public (line 332)
- Removed obsolete `onTourDataReady` callback (was line 44)

### AudioTourView.swift
- Updated `startAudioTour()` to use `prepareTour()` (lines 474-501)
- Opens map immediately after preparation
- Starts narration in background Task

## Testing Instructions

### Test 1: Map Appears Immediately
1. Open app in simulator
2. Go to Discover tab
3. Add 2-3 POIs to tour using + button
4. Go to Audio Tour tab
5. Click **Start Tour**

**Expected**:
- Console shows `🚀 Preparing tour with 2 POIs...`
- Console shows `🗺️ 📸 Snapshot captured: mapPOIs.count=2`
- Console shows `🗺️ 🚨 Opening map with 2 POIs`
- Map sheet opens immediately (within 1 second)
- Map shows POI markers and blue route line
- Map auto-zooms to fit all POIs

### Test 2: Narration Plays While Map Visible
1. Continue from Test 1
2. Listen to audio while watching map

**Expected**:
- Welcome message starts playing immediately after map opens
- Console shows `🔊 Starting welcome introduction (background)`
- Map remains visible during entire welcome
- Map is visible during POI introductions

### Test 3: Map Zooms During POI Introduction
1. Continue from Test 2
2. Watch map during "Stop number 1: [POI Name]" narration

**Expected**:
- Map zooms in to first POI when its name is spoken
- Console shows `🎯 Zooming to POI 0: [POI Name]`
- Console shows `🗺️ AudioTourManager: introducingPOIIndex changed to 0`
- Map animates zoom smoothly
- After narration, map zooms back out
- Repeats for each POI

## Known Issues & Solutions

### Issue: Map Shows 0 POIs
**Symptom**: Console shows `mapPOIs.count=0`

**Cause**: `prepareTour()` not completing before snapshot

**Fix**: Check that `prepareTour()` is being awaited properly

### Issue: Map Doesn't Zoom During Introduction
**Symptom**: Map shows POIs but doesn't zoom during narration

**Cause**: `introducingPOIIndex` changes not propagating to map

**Debug**: Check for these console logs:
```
🗺️ AudioTourManager: introducingPOIIndex changed to 0
```

If log appears, map should zoom. If not, `playWelcomeIntroduction()` not running.

### Issue: No Audio
**Symptom**: Map appears but no narration plays

**Cause**: Background Task not starting `playWelcomeIntroduction()`

**Debug**: Look for `🔊 Starting welcome introduction (background)` in console

## Build Status

```bash
swift build
```

Output:
```
Build complete! (5.51s)
```

✅ No compilation errors
✅ No critical warnings
✅ Ready for testing

## Summary of Complete Solution

### Key Architectural Change
Split tour management into two phases:
1. **Preparation Phase** (`prepareTour()`) - Fast, returns immediately
   - Sets currentPOIs and sessions
   - Loads images in parallel
   - Makes data available for map

2. **Narration Phase** (`playWelcomeIntroduction()`) - Slow, runs in background
   - Plays welcome message
   - Introduces each POI with zoom coordination
   - Takes 30+ seconds to complete

### Why This Works
- **Immediate Data Availability**: POIs/sessions are set synchronously in `prepareTour()`
- **Non-Blocking UI**: Map opens immediately, no waiting for narration
- **Background Narration**: Audio plays in Task while map is visible
- **Coordinated Zoom**: Map observes `introducingPOIIndex` to zoom during narration

### Previous Attempts That Failed
1. ❌ Awaiting full `startTour()` - blocked for 30s
2. ❌ Background task + delay - timing unreliable
3. ❌ Polling loop - @Observable doesn't wake loops
4. ❌ Callback pattern - closures don't capture properly

### Final Solution
✅ Split preparation from narration - reliable and immediate

## Next Steps

Run the app and execute Test 1 above. The map should now:
1. Open immediately when tour starts
2. Display POIs and route correctly
3. Remain visible during welcome introduction
4. Zoom to each POI as it's being introduced
5. Respond to dynamic changes (introducingPOIIndex)

Look for the expected console output pattern. If any issues occur, check the "Known Issues & Solutions" section.
