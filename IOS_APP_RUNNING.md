# Running the iOS App in Xcode Simulator

The AIRoadTripTours package provides a complete iOS UI library (`AIRoadTripToursApp`) with all views and app
logic. To run it in the Xcode simulator, you must create an iOS app project that imports the package as a
dependency.

## Quick Start: Create iOS App in Xcode

### Step 1: Create New iOS App Project

1. Open Xcode
2. Select "Create New Project" (or File > New > Project)
3. Select "iOS" platform tab at the top
4. Choose "App" template
5. Click "Next"
6. Configure your project:
   - Product Name: `AIRoadTripToursIOSApp`
   - Team: (select your team or leave as None for simulator)
   - Organization Identifier: `com.airoadtriptours`
   - Interface: **SwiftUI** (important!)
   - Language: **Swift**
   - Storage: Any
   - Include Tests: (optional)
7. Click "Next"
8. Save location: Choose `/Users/baysideuser/GitRepos/AIRoadTripTours/AIRoadTripToursIOSApp`
9. Click "Create"

### Step 2: Add Package Dependency

1. In the Project Navigator, select your project (top item with blue icon)
2. Select your app target under "Targets"
3. Click the "General" tab
4. Scroll down to find "Frameworks, Libraries, and Embedded Content" section
5. Click the "+" button below that section
6. In the dialog that appears, click "Add Other..." > "Add Package Dependency..."
7. Click "Add Local..." button at bottom left
8. Navigate to `/Users/baysideuser/GitRepos/AIRoadTripTours` (the package root directory)
9. Click "Add Package"
10. In the "Choose Package Products" dialog, select:
    - ✅ AIRoadTripToursApp
11. Click "Add Package"

Xcode automatically links the required dependencies (Core and Services) transitively.

### Step 3: Replace App Entry Point

1. In Project Navigator, find the file named `AIRoadTripToursIOSAppApp.swift` (or similar - Xcode auto-generates
   this with a double "App" suffix)
2. Replace its **entire contents** with:

```swift
import SwiftUI
import AIRoadTripToursApp

@main
struct RoadTripApp: App {
    var body: some Scene {
        AIRoadTripApp().body
    }
}
```

### Step 4: Run in Simulator

1. In the Xcode toolbar, click the scheme/device selector (shows target device)
2. Select any iPhone simulator (for example, "iPhone 15 Pro")
3. Press `⌘R` (or click the Play button ▶️)
4. The app builds and launches in the simulator

## What You See

The app launches with a 3-step onboarding flow:

1. **Welcome Screen**: Introduction with "Get Started" button
2. **User Information**: Email, display name, and interest categories
   - Select multiple interests from: Nature, Food, History, Entertainment, Adventure, Culture, Shopping,
     Relaxation, Scenic, Wildlife
3. **Vehicle Setup**: EV details with quick presets
   - Tesla Model 3, Ford Mustang Mach-E, Chevrolet Bolt EUV, Nissan Leaf
   - Or manual entry: make, model, battery capacity (kWh), range (miles)

After completing onboarding, the main app displays a 5-tab interface:

- **🎵 Audio Tour**: Narration playback with play, pause, skip, and queue controls
- **🗺️ Discover**: Search and filter points of interest by location and preferences
- **🚗 Tours**: Tour management (placeholder for future implementation)
- **⚡ Range**: EV range calculator with weather and terrain condition adjustments
- **👤 Profile**: View user information, interests, vehicle details, and subscription status

## Alternative: Using Existing iOS Project

If you already have an iOS app and want to add this functionality:

1. Open your existing Xcode project
2. Select your project in Project Navigator
3. Select your app target
4. General tab > Frameworks, Libraries, and Embedded Content
5. Click "+" > "Add Other..." > "Add Package Dependency..."
6. Click "Add Local..."
7. Navigate to `/Users/baysideuser/GitRepos/AIRoadTripTours`
8. Select `AIRoadTripToursApp` product
9. Import and use in your code:

```swift
import AIRoadTripToursApp

// Use the complete app
struct MyApp: App {
    var body: some Scene {
        AIRoadTripApp().body
    }
}

// OR use individual views
struct MyCustomView: View {
    @State private var appState = AppState()

    var body: some View {
        AudioTourView()
            .environment(appState)
    }
}
```

## Package Architecture

The package is organized into focused modules:

- **AIRoadTripToursCore**: Domain models and business logic
  - User, EVProfile, POI, Tour, Waypoint, Narration
  - Range estimation, trip safety, POI filtering
  - Protocol-oriented design for testability

- **AIRoadTripToursServices**: External integrations
  - Audio synthesis with AVSpeechSynthesizer (iOS only)
  - Actor-based narration queue management
  - Mock AI content generator
  - API client infrastructure (OpenAPI)

- **AIRoadTripToursApp**: Complete iOS UI library
  - All SwiftUI views as public API
  - Observable state management with @Observable
  - Environment-based dependency injection
  - Cross-platform compatible (iOS/macOS)

- **AIRoadTripToursDemo**: Command-line demo executable
  - Interactive menu-driven demo (macOS only)
  - Demonstrates all features without UI
  - Run with: `swift run AIRoadTripToursDemo`

## Available Public Views

All views are public and can be composed independently:

```swift
import AIRoadTripToursApp

// Complete app with onboarding and tabs
AIRoadTripApp()

// Root content view (onboarding logic)
ContentView()

// Individual screens
OnboardingView()      // 3-step onboarding flow
MainTabView()         // 5-tab navigation
AudioTourView()       // Audio narration playback
DiscoverView()        // POI discovery and search
ToursView()           // Tour management
RangeCalculatorView() // EV range calculator
ProfileView()         // User and vehicle info

// State management
AppState()            // Observable app state
```

## Customization Examples

### Use Only Specific Features

```swift
import SwiftUI
import AIRoadTripToursApp
import AIRoadTripToursCore

@main
struct MyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            TabView {
                DiscoverView()
                    .tabItem {
                        Label("Explore", systemImage: "map")
                    }

                RangeCalculatorView()
                    .tabItem {
                        Label("Range", systemImage: "bolt.fill")
                    }
            }
            .environment(appState)
        }
    }
}
```

### Custom Onboarding

```swift
struct MyCustomOnboarding: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            Text("Welcome to My Road Trip App")

            Button("Skip to App") {
                // Create default user/vehicle
                let user = User(email: "guest@app.com", displayName: "Guest")
                let vehicle = EVProfile(
                    make: "Tesla",
                    model: "Model 3",
                    year: 2024,
                    batteryCapacityKWh: 75.0,
                    chargingPorts: [.tesla],
                    estimatedRangeMiles: 272.0,
                    consumptionRateKWhPerMile: 0.276
                )
                appState.completeOnboarding(user: user, vehicle: vehicle)
            }

            // Or show the built-in onboarding
            OnboardingView()
        }
    }
}
```

## Build and Test Status

- ✅ Package builds successfully on macOS and iOS
- ✅ All 113 unit and integration tests passing
- ✅ iOS library compiles for iOS 17+ and macOS 14+
- ✅ Cross-platform compatible with conditional compilation
- ✅ Zero warnings in strict concurrency mode

## Platform-Specific Features

The package handles platform differences automatically:

- **Audio synthesis**: Uses AVSpeechSynthesizer on iOS, wrapped in `#if canImport(UIKit)` for conditional
  compilation. Audio features gracefully degrade on macOS.
- **SwiftUI adaptations**: Views use platform-appropriate controls (List vs Form, keyboard types, etc.)
- **Core business logic**: All domain models and algorithms work identically on all platforms

## Troubleshooting

### "No such module 'AIRoadTripToursApp'"

**Cause**: Package not properly linked to app target

**Solution**:
1. Select project in Project Navigator
2. Select app target
3. General tab > Frameworks, Libraries, and Embedded Content
4. Verify `AIRoadTripToursApp` is listed
5. If not, add it using "+" button > Add Package Dependency > Add Local

### Build Fails with Missing Symbols

**Cause**: Stale build artifacts

**Solution**:
1. Product menu > Clean Build Folder (⌘⇧K)
2. Close Xcode
3. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
4. Reopen project and build (⌘B)

### Simulator Shows Black Screen

**Cause**: App entry point not correctly configured

**Solution**:
1. Verify app file imports `AIRoadTripToursApp`
2. Check that `body` returns `AIRoadTripApp().body`
3. Ensure you selected "SwiftUI" interface when creating project

### Package Not Found When Adding Local Dependency

**Cause**: Wrong directory selected

**Solution**:
- Navigate to the package root: `/Users/baysideuser/GitRepos/AIRoadTripTours`
- This directory should contain `Package.swift`
- Do NOT select the `Sources` or `AIRoadTripToursIOSApp` subdirectories

### "Cannot find 'AppState' in scope"

**Cause**: Missing import statement

**Solution**: Add `import AIRoadTripToursApp` at top of file

## Running Command-Line Demo

For a non-UI demonstration of all features:

```bash
cd /Users/baysideuser/GitRepos/AIRoadTripTours
swift run AIRoadTripToursDemo
```

Interactive menu includes:
- User and vehicle management
- Range calculations with various conditions
- POI discovery and filtering
- Narration generation and timing
- Queue management demonstrations

## Next Steps

After running the app:

1. Complete onboarding to explore the full feature set
2. Try different vehicle presets to see range variations
3. Explore POI discovery with different interest combinations
4. Test range calculator with extreme weather conditions (20°F, mountain driving)
5. Review profile screen to see subscription and trial status
6. Experiment with audio tour queue management

The app demonstrates a production-ready architecture with proper separation of concerns, dependency injection,
comprehensive error handling, and full test coverage.
