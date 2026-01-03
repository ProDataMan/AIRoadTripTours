# Opening the iOS App Project in Xcode

## Issue: "Already opened from another project or workspace"

This error occurs because the Swift package workspace is conflicting with the iOS app project.

## Solution

### Step 1: Close Xcode completely

Quit Xcode using ⌘Q or Xcode > Quit.

### Step 2: Open the iOS app project directly

**Important**: Do NOT open Package.swift. Open the iOS app project instead:

```bash
open AIRoadTripToursIOSApp.xcodeproj
```

Or in Finder:
1. Navigate to `/Users/baysideuser/GitRepos/AIRoadTripTours/`
2. Double-click `AIRoadTripToursIOSApp.xcodeproj` (has the Xcode icon)
3. Do NOT open `Package.swift`

### Why This Happens

The Swift package (`Package.swift`) and the iOS app project (`AIRoadTripToursIOSApp.xcodeproj`) both reference the same package directory. When you have Package.swift open in Xcode, it locks the package and prevents the iOS app from loading it as a dependency.

### What to Open

✅ **CORRECT**: `AIRoadTripToursIOSApp.xcodeproj`
- This is the iOS app
- It includes the package as a dependency
- Use this for app development

❌ **WRONG**: `Package.swift`
- This is just the package
- Used for library/CLI development only
- Conflicts with the iOS app project

### If You Still Get the Error

1. Quit Xcode completely (⌘Q)
2. Delete workspace cache:
   ```bash
   rm -rf .swiftpm/xcode/
   rm -rf ~/Library/Developer/Xcode/DerivedData/AIRoadTripToursIOSApp-*
   ```
3. Open the project:
   ```bash
   open AIRoadTripToursIOSApp.xcodeproj
   ```

### Running the App

Once the project is open:
1. Select target: **AIRoadTripToursIOSApp**
2. Select device: **iPhone 17** (or any iPhone simulator)
3. Press **⌘R** to build and run

The app should launch in the simulator with the onboarding screen.

## Working with Both Package and App

If you need to work on both:

1. **Package development**: Open `Package.swift` in Xcode
   - Run tests: ⌘U or `swift test --no-parallel`
   - Edit library code in Sources/

2. **App development**: Open `AIRoadTripToursIOSApp.xcodeproj`
   - Build and run app: ⌘R
   - Package code is included as dependency

**Never have both open in Xcode at the same time.**

---

**Quick Command to Open Project**:
```bash
cd /Users/baysideuser/GitRepos/AIRoadTripTours
open AIRoadTripToursIOSApp.xcodeproj
```
