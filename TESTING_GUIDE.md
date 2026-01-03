# App Testing Guide

## Quick Start Testing

### 1. Launch the App

```bash
open /Users/baysideuser/GitRepos/AIRoadTripTours/AIRoadTripToursIOSApp/AIRoadTripToursIOSApp.xcodeproj
```

**Note**: Use the outer-level `.xcodeproj` file, not the nested one inside the AIRoadTripToursIOSApp subdirectory.

In Xcode:
- Select iPhone 17 or iPhone 17 Pro simulator
- Press ⌘R to build and run
- App should launch in simulator within 10-15 seconds

### 2. Test Onboarding Flow

**Step 1: Welcome Screen**
- ✅ Verify app icon and title display
- ✅ Read welcome message
- ✅ Tap "Get Started" button
- Should transition to user info screen

**Step 2: User Information**
- ✅ Enter email: `test@example.com`
- ✅ Enter display name: `Test User`
- ✅ Select 2-3 interests (tap multiple categories):
  - Try: Nature, Food, Scenic
- ✅ Verify "Next" button enables when form is valid
- ✅ Tap "Next" to proceed to vehicle setup

**Step 3: Vehicle Setup**
- ✅ Tap "Tesla Model 3" preset button
- ✅ Verify fields auto-populate:
  - Make: Tesla
  - Model: Model 3
  - Battery: 75 kWh
  - Range: 310 miles
- ✅ Try changing to "Ford Mustang Mach-E" preset
- ✅ Tap "Get Started" to complete onboarding
- Should transition to main tab interface

### 3. Test Main Tab Navigation

**Audio Tour Tab (🎵)**
- ✅ Verify tab selected by default
- ✅ See "No narrations in queue" message
- ✅ Tap "Generate Sample Narration" button
- ✅ Observe narration appears in queue
- ✅ Tap Play button (▶️)
- ✅ Listen for audio playback (requires device audio on)
- ✅ Tap Pause button (⏸)
- ✅ Tap Resume/Play again
- ✅ Tap Skip button (⏭) to move to next
- ✅ Tap Stop button (⏹) to clear playback

**Discover Tab (🗺️)**
- ✅ Tap Discover tab
- ✅ See list of sample POIs:
  - Multnomah Falls
  - Portland Japanese Garden
  - Pike Place Market
  - Columbia River Gorge
  - etc.
- ✅ Scroll through POI list
- ✅ Tap a POI to see details
- ✅ Verify details display:
  - Name, category, description
  - Distance (if location available)
  - Rating and price level
  - Operating hours
  - Contact info

**Tours Tab (🚗)**
- ✅ Tap Tours tab
- ✅ See "Coming Soon" placeholder
- ✅ Verify message about future tour planning features

**Range Calculator Tab (⚡)**
- ✅ Tap Range tab
- ✅ Verify vehicle info displays (Tesla Model 3)
- ✅ Enter trip details:
  - Distance: 150 miles
  - Temperature: 70°F (default)
  - Elevation: 0 feet (default)
- ✅ Tap "Calculate Range" button
- ✅ Verify results display:
  - Estimated range in miles
  - Trip safety status (green checkmark or red warning)
  - Recommendation message
- ✅ Try cold weather scenario:
  - Distance: 150 miles
  - Temperature: 20°F
  - Elevation: 0 feet
- ✅ Tap "Calculate Range"
- ✅ Verify range is lower due to cold weather
- ✅ Try mountain scenario:
  - Distance: 100 miles
  - Temperature: 70°F
  - Elevation: 3000 feet
- ✅ Verify range is lower due to elevation gain

**Profile Tab (👤)**
- ✅ Tap Profile tab
- ✅ Verify user information section:
  - Email: test@example.com
  - Display Name: Test User
  - Account Created: today's date
  - Trial Active: Yes (green checkmark)
  - Premium Access: Yes
- ✅ Verify interests section shows selected categories
- ✅ Verify vehicle section shows:
  - Tesla Model 3 2024
  - Battery: 75 kWh
  - Range: 310 miles
  - Charging ports: NACS, CCS

### 4. Test Edge Cases

**Invalid Input Handling**
- ✅ Go back to onboarding (restart app)
- ✅ Try submitting user info without email
- ✅ Verify "Next" button is disabled
- ✅ Try submitting with invalid email (no @)
- ✅ Verify validation prevents submission
- ✅ Try submitting vehicle info with non-numeric battery capacity
- ✅ Verify proper error handling

**Navigation Flow**
- ✅ Switch between tabs rapidly
- ✅ Verify no crashes or UI glitches
- ✅ Verify state persists when switching tabs
- ✅ Verify back navigation works in detail views

**Performance**
- ✅ Monitor CPU usage (should be low when idle)
- ✅ Check memory usage (should be < 100MB)
- ✅ Verify smooth scrolling in lists
- ✅ Verify instant tab switching

### 5. Test Audio Features (iOS Specific)

**Audio Playback**
- ✅ Ensure simulator volume is on
- ✅ Generate narration and play
- ✅ Verify audio plays through speakers
- ✅ Test pause/resume maintains position
- ✅ Test skip moves to next narration
- ✅ Verify queue updates in real-time

**Queue Management**
- ✅ Generate 3+ narrations
- ✅ Verify all appear in queue
- ✅ Play through queue sequentially
- ✅ Verify status updates (pending → playing → completed)
- ✅ Test "Clear All" removes all narrations

## Known Issues / Expected Behavior

### Current Limitations

**POI Discovery**
- Uses mock/sample data (10 curated POIs)
- No real location services integration yet
- Distance calculations are simulated
- No real-time search/filtering

**Audio Narration**
- Uses iOS text-to-speech (AVSpeechSynthesizer)
- Content is mock-generated placeholder text
- No real AI generation (ready for OpenAI integration)
- English only (ready for localization)

**Range Calculator**
- Uses simplified physics model
- Weather data is manual input (no weather API)
- No real-time battery level reading
- No actual EV integration

**Tours**
- Placeholder UI only
- Tour creation not yet implemented
- Route planning pending Phase 6

### Expected Behavior

**Trial Status**
- All new users get 90-day trial
- Premium access granted during trial
- No actual subscription payment processing

**Data Persistence**
- State resets on app restart
- No cloud sync yet
- No local storage (SwiftData/CoreData)

**Offline Mode**
- App works fully offline (all features are local)
- No network requests yet
- Ready for backend integration in Phase 5

## Testing Checklist

### Pre-Flight
- [ ] All package tests passing (113/113)
- [ ] App builds without errors
- [ ] No compiler warnings
- [ ] Clean derived data if needed

### Onboarding
- [ ] Welcome screen displays correctly
- [ ] User info validation works
- [ ] Interest selection allows multiple choices
- [ ] Vehicle presets populate correctly
- [ ] Onboarding completes successfully

### Main Features
- [ ] All 5 tabs accessible
- [ ] Audio playback works
- [ ] POI list displays
- [ ] Range calculator produces results
- [ ] Profile shows correct data

### Edge Cases
- [ ] Invalid input rejected
- [ ] Empty states display properly
- [ ] Navigation maintains state
- [ ] No memory leaks
- [ ] No crashes on typical use

### Performance
- [ ] Smooth scrolling
- [ ] Instant tab switching
- [ ] Audio plays without stuttering
- [ ] CPU/memory usage reasonable

## Test Results Template

```
Test Date: YYYY-MM-DD
Tester: [Name]
Device: iPhone 17 Simulator / iOS 26.2
Build: Debug

[X] Onboarding flow complete
[X] Audio tour functional
[X] Discover POIs working
[X] Range calculator accurate
[X] Profile displays correctly

Issues Found:
1. [Description]
2. [Description]

Notes:
- [Additional observations]
```

## Next Steps After Testing

Once testing is complete and app is validated:

1. **Document any bugs** found during testing
2. **Prioritize issues** (critical, major, minor)
3. **Fix blocking issues** before Phase 5
4. **Move to Phase 5**: Backend Integration
   - API design and specification
   - Backend service architecture
   - Authentication implementation
   - Cloud data sync

## Quick Commands

```bash
# Run all package tests
cd /Users/baysideuser/GitRepos/AIRoadTripTours
swift test --no-parallel

# Build package
swift build

# Run CLI demo
swift run AIRoadTripToursDemo

# Open iOS app in Xcode
cd AIRoadTripToursIOSApp
open AIRoadTripToursIOSApp.xcodeproj

# Clean build (if issues)
# In Xcode: Product > Clean Build Folder (⌘⇧K)
```
