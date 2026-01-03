# AI Road Trip Tours - Production iOS App

## Overview

This is the production iOS application for AI Road Trip Tours, an electric vehicle road trip planning app with
AI-generated narrations. The app provides personalized tour recommendations, EV range calculations, and audio
narration playback for points of interest along your route.

## Architecture

The application follows a clean architecture pattern with clear separation of concerns across three package
modules plus the iOS app target:

```
AIRoadTripToursIOSApp/          (iOS App Bundle - Production App)
├── AIRoadTripToursIOSAppApp.swift   Entry point, imports and launches AIRoadTripApp
└── [Xcode project files]

AIRoadTripTours/                (Swift Package - Core Libraries)
├── Sources/
│   ├── AIRoadTripToursCore/         Domain layer (models, business logic)
│   ├── AIRoadTripToursServices/     Service layer (audio, API clients)
│   ├── AIRoadTripToursApp/          Presentation layer (SwiftUI views)
│   └── AIRoadTripToursDemo/         CLI demo (development tool)
└── Tests/
```

### Layer Responsibilities

**AIRoadTripToursCore** - Domain Layer
- Pure Swift business logic with no platform dependencies
- Domain models: User, EVProfile, POI, Tour, Waypoint, Narration
- Business rules: Range estimation, trip safety, POI filtering
- Protocol-oriented design for dependency injection
- 100% test coverage with 70+ unit tests

**AIRoadTripToursServices** - Service Layer
- External integrations and platform-specific features
- Audio synthesis using AVSpeechSynthesizer (iOS only)
- Actor-based narration queue for thread-safe audio management
- Mock AI content generator (ready for OpenAI integration)
- OpenAPI client infrastructure for future backend services

**AIRoadTripToursApp** - Presentation Layer
- Complete SwiftUI UI implementation
- Observable state management with @Observable macro
- Environment-based dependency injection
- Cross-platform (iOS/macOS) with conditional compilation
- All views are public API for maximum reusability

**AIRoadTripToursIOSApp** - Application Bundle
- Minimal wrapper that launches AIRoadTripApp
- Contains no business logic or UI code
- Links package libraries as dependencies
- Manages app lifecycle and configuration

## Key Features

### 1. User Onboarding (3 Steps)

**Welcome Screen**
- App introduction and value proposition
- Single "Get Started" call-to-action

**User Profile Setup**
- Email and display name collection
- Multi-select interest categories:
  - Nature, Food, History, Entertainment
  - Adventure, Culture, Shopping, Relaxation
  - Scenic views, Wildlife watching
- Interest-based POI personalization

**Vehicle Configuration**
- Quick presets for popular EVs:
  - Tesla Model 3 (75 kWh, 272 mi range)
  - Ford Mustang Mach-E (91 kWh, 312 mi range)
  - Chevrolet Bolt EUV (65 kWh, 247 mi range)
  - Nissan Leaf (60 kWh, 212 mi range)
- Manual entry: make, model, battery capacity, range
- Automatic consumption rate calculation

### 2. Audio Tour (Phase 4 Complete)

**Narration Playback**
- Play, pause, resume, stop controls
- Skip forward to next narration
- Real-time playback state display
- Queue position indicator

**Content Generation**
- AI-generated narrations tailored to POI types
- Duration targeting (typical: 90-180 seconds)
- User interest personalization
- Natural language quality content

**Queue Management**
- Actor-based concurrent queue (thread-safe)
- Status tracking: pending, playing, completed, failed
- Automatic sequential playback
- Clear all functionality

**Timing Calculation**
- Precise trigger distance calculation
- Speed-adaptive scheduling
- Target arrival window: 60-120 seconds after narration ends
- Minimum safe distance validation (0.5 miles from POI)

### 3. POI Discovery

**Search Capabilities**
- Location-based radius search
- Category filtering (10+ categories)
- Interest matching with user profile
- EV charger-specific filter
- Rating and price level filters

**POI Data Structure**
- Name, description, category
- Geographic coordinates with address
- Operating hours and open/closed status
- Ratings (average + total reviews)
- Price level (1-4 scale)
- Contact info (phone, website)
- Tags for enhanced filtering
- Data source tracking (Yelp, Google, Curated)

**Sample Data Included**
- 10+ curated Pacific Northwest POIs
- Multnomah Falls, Columbia River Gorge
- Pike Place Market, Cannon Beach
- Mount Hood, Crater Lake
- Voodoo Doughnut, Powell's Books

### 4. EV Range Calculator

**Condition Modeling**
- Temperature effects (cold weather penalties)
- Elevation changes (uphill consumption)
- Cold soak calculations (overnight parking)
- Average speed adjustments
- Combined condition scenarios

**Safety Analysis**
- Required battery percentage calculation
- 15% safety buffer included
- Trip feasibility assessment
- Charging recommendation alerts

**Quick Scenarios**
- Standard conditions (70°F, flat terrain)
- Cold weather (20°F)
- Winter road trip (20°F + 8hr parking)
- Mountain driving (+3000ft elevation)
- Extreme conditions (all factors combined)

### 5. Profile Management

**User Information Display**
- Email and display name
- Account creation date
- Trial expiration tracking (90-day default)
- Subscription status
- Premium access indicator

**Interest Management**
- View selected interests with categories
- Visual category icons
- Sorted alphabetical display

**Vehicle Fleet**
- Multiple vehicle support
- Active vehicle selection
- Complete specifications display:
  - Make, model, year
  - Battery capacity (kWh)
  - EPA range estimate (miles)
  - Consumption rate (kWh/mile)
  - Supported charging port types

## State Management

**AppState (Observable)**
- Current user profile
- Current vehicle selection
- Onboarding completion status
- POI repository instance
- Range estimator instance
- Environment propagation to all views

**Benefits of @Observable**
- Automatic view updates on state changes
- No manual @Published properties
- Improved performance with granular updates
- Simpler syntax than ObservableObject

## Dependency Injection

**Environment-Based Pattern**
```swift
@Environment(AppState.self) private var appState
```

**Benefits**
- Testable views (inject mock state)
- Loose coupling between layers
- Easy to swap implementations
- Follows SwiftUI conventions

## Testing Strategy

**Unit Tests (70% of suite)**
- Pure business logic in Core module
- Fast execution (<1ms per test)
- No external dependencies
- Protocol-based mocking

**Integration Tests (20% of suite)**
- Service layer functionality
- Actor concurrency validation
- Audio synthesis integration
- Repository implementations

**End-to-End Tests (10% of suite)**
- Complete feature workflows
- Multi-component interactions
- User scenario coverage

**Current Status**
- 113 tests passing
- Zero test failures
- ~0.5s total execution time
- Run with: `swift test --no-parallel`

## Platform Compatibility

**iOS 17+**
- Full feature support
- AVSpeechSynthesizer audio
- Native SwiftUI controls
- Optimized for iPhone

**macOS 14+**
- Development and testing support
- Audio features gracefully degrade
- Adapted UI controls (List vs Form)
- Full business logic compatibility

**Conditional Compilation**
```swift
#if canImport(UIKit)
// iOS-specific audio synthesis
let audioService = AVSpeechNarrationAudioService()
#endif
```

## Build Configuration

**Debug Build**
- Includes all logging
- Full error messages
- Development shortcuts
- Simulator-optimized

**Release Build**
- Optimized performance
- Minimal logging
- Production error handling
- Device-ready binaries

**Current Build Status**
- ✅ Builds successfully (< 3s)
- ✅ All tests passing
- ✅ Zero warnings
- ✅ Strict concurrency enabled

## Running the App

### In Xcode Simulator

1. Open project:
   ```bash
   cd /Users/baysideuser/GitRepos/AIRoadTripTours/AIRoadTripToursIOSApp
   open AIRoadTripToursIOSApp.xcodeproj
   ```

2. Select simulator device:
   - iPhone 17 (recommended)
   - iPhone 17 Pro
   - iPhone 16e
   - Any iPad simulator

3. Build and run (⌘R)

4. Complete onboarding flow to access full features

### Command-Line Build

```bash
cd /Users/baysideuser/GitRepos/AIRoadTripTours/AIRoadTripToursIOSApp
xcodebuild -project AIRoadTripToursIOSApp.xcodeproj \
  -scheme AIRoadTripToursIOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

### CLI Demo (Development)

```bash
cd /Users/baysideuser/GitRepos/AIRoadTripTours
swift run AIRoadTripToursDemo
```

Interactive menu for testing all features without UI.

## Next Development Steps

### Phase 5: Backend Integration

**API Implementation**
- User authentication and registration
- Cloud-based user profile storage
- POI data synchronization
- Real-time tour updates

**Services to Integrate**
- OpenAI GPT-4 for narration generation
- Google Places API for POI discovery
- NREL API for EV charger locations
- Mapbox for routing and navigation

**Infrastructure**
- OpenAPI code generation (already configured)
- URLSession-based HTTP client
- Authentication token management
- Offline mode with local caching

### Phase 6: Tour Planning

**Route Generation**
- Multi-waypoint tour creation
- Automatic charging stop insertion
- Trip safety validation
- Time estimation with traffic

**Tour Management**
- Save and load tours
- Share tours with other users
- Favorite tours collection
- Tour rating and reviews

**Navigation Integration**
- Turn-by-turn directions
- Live location tracking
- Automatic narration triggering
- Real-time range updates

### Phase 7: Advanced Features

**Social Features**
- User-generated tour sharing
- Community ratings and reviews
- Friend recommendations
- Group tour planning

**Premium Features**
- Unlimited narration generation
- Offline map downloads
- Advanced route optimization
- Priority customer support

**Analytics**
- Usage tracking
- Popular destinations
- User preference analysis
- Performance monitoring

### Phase 8: Polish and Launch

**Performance Optimization**
- Image caching and lazy loading
- Background audio processing
- Battery usage optimization
- Network request batching

**Accessibility**
- VoiceOver support
- Dynamic Type scaling
- High contrast mode
- Reduced motion options

**Localization**
- Multi-language support
- Regional POI preferences
- Currency and unit conversion
- Cultural content adaptation

**App Store Preparation**
- Screenshots and preview videos
- App Store description
- Privacy policy and terms
- Beta testing program

## Development Workflow

### Making Changes

1. **Edit package code**:
   ```bash
   cd /Users/baysideuser/GitRepos/AIRoadTripTours
   # Edit files in Sources/
   ```

2. **Run tests**:
   ```bash
   swift test --no-parallel
   ```

3. **Build package**:
   ```bash
   swift build
   ```

4. **Test in iOS app**:
   - Changes automatically picked up
   - Clean build if needed (⌘⇧K in Xcode)
   - Run app in simulator (⌘R)

### Adding New Features

1. Write tests first (TDD)
2. Implement in appropriate module:
   - Core: business logic
   - Services: external integrations
   - App: UI and user interactions
3. Update public API if needed
4. Document in code and README
5. Verify app integration

### Debugging

**Package Code**
- Add breakpoints in Xcode
- Use `print()` or `Logger` for logging
- Check test output for failures

**iOS App**
- Normal Xcode debugging (breakpoints, LLDB)
- View hierarchy inspection
- Memory graph debugging

## Project Status

**Current Phase**: Phase 4 Complete (Narration Engine)

**Completed Features**
- ✅ User profile management
- ✅ EV vehicle configuration
- ✅ Range estimation and trip safety
- ✅ POI discovery and filtering
- ✅ AI narration generation
- ✅ Audio playback with queue management
- ✅ Complete iOS UI

**In Progress**
- 🔄 Production app deployment setup
- 🔄 Backend integration planning

**Upcoming**
- ⏳ Tour planning and route generation
- ⏳ Real-time navigation
- ⏳ Social features
- ⏳ App Store submission

## Technical Specifications

**Language**: Swift 6.1+
**Minimum iOS**: 17.0
**UI Framework**: SwiftUI
**Concurrency**: Swift Concurrency (async/await, actors)
**Architecture**: Clean Architecture + MVVM
**Testing**: Swift Testing framework
**Package Manager**: Swift Package Manager
**Build System**: Xcode 26.2+

## Repository Structure

```
AIRoadTripTours/
├── Package.swift                    Package manifest
├── README.md                        Project overview
├── IOS_APP_RUNNING.md              This file
├── Sources/
│   ├── AIRoadTripToursCore/        Business logic
│   ├── AIRoadTripToursServices/    Platform services
│   ├── AIRoadTripToursApp/         SwiftUI views
│   └── AIRoadTripToursDemo/        CLI demo
├── Tests/
│   ├── AIRoadTripToursCoreTests/
│   └── AIRoadTripToursServicesTests/
└── AIRoadTripToursIOSApp/          iOS app project
    ├── AIRoadTripToursIOSApp.xcodeproj
    └── AIRoadTripToursIOSApp/
        └── AIRoadTripToursIOSAppApp.swift
```

## Contact and Support

For questions or issues with development, refer to:
- Package documentation in source files
- Test files for usage examples
- This README for architecture guidance
- Git history for implementation decisions

## License

Proprietary - All rights reserved
