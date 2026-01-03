# Creating the iOS App Project (Clean Structure)

## Current Clean Structure

```
AIRoadTripTours/                      (Root - Git repo)
├── Package.swift                     Swift package
├── Sources/
│   ├── AIRoadTripToursCore/
│   ├── AIRoadTripToursServices/
│   ├── AIRoadTripToursApp/
│   └── AIRoadTripToursDemo/
├── Tests/
└── AIRoadTripToursIOSApp/           (iOS App - will be created here)
    └── AIRoadTripToursIOSAppApp.swift  (starter file already created)
```

## Steps to Create iOS App Project

### 1. Open Xcode and Create New Project

1. Open Xcode
2. File > New > Project
3. Select **iOS** platform
4. Choose **App** template
5. Click **Next**

### 2. Configure Project

**Important settings**:
- Product Name: `AIRoadTripToursIOSApp`
- Team: (your team or None)
- Organization Identifier: `com.airoadtriptours`
- Interface: **SwiftUI**
- Language: **Swift**
- Storage: **None**
- Include Tests: **Unchecked**

Click **Next**

### 3. Save Location (CRITICAL)

**Save location**: Navigate to `/Users/baysideuser/GitRepos/AIRoadTripTours`

**IMPORTANT**:
- Save directly in `/Users/baysideuser/GitRepos/AIRoadTripTours`
- NOT in a subfolder
- Xcode will create the `AIRoadTripToursIOSApp.xcodeproj` here

Result should be:
```
AIRoadTripTours/
├── AIRoadTripToursIOSApp.xcodeproj  ← Project file at root
├── AIRoadTripToursIOSApp/           ← App files folder
│   └── AIRoadTripToursIOSAppApp.swift
├── Package.swift
└── Sources/
```

Click **Create**

### 4. Replace Auto-Generated App File

Xcode created `AIRoadTripToursIOSApp/AIRoadTripToursIOSAppApp.swift` with default code.

**Replace the entire contents** with:

```swift
//
//  AIRoadTripToursIOSAppApp.swift
//  AIRoadTripToursIOSApp
//
//  Production iOS app for AI Road Trip Tours
//

import SwiftUI
import AIRoadTripToursApp

@main
struct AIRoadTripToursIOSAppApp: App {
    var body: some Scene {
        AIRoadTripApp().body
    }
}
```

**Note**: The file I already created at `AIRoadTripToursIOSApp/AIRoadTripToursIOSAppApp.swift` has this content, but Xcode's version will overwrite it - that's OK, just make sure it has this content.

### 5. Delete Unnecessary ContentView.swift

Xcode auto-generates a `ContentView.swift` file - you don't need it.

- In Project Navigator, find `ContentView.swift`
- Right-click > Delete > Move to Trash

### 6. Add Local Package Dependency

**In Project Navigator**:
1. Select the **project** (blue icon at top)
2. Select the **AIRoadTripToursIOSApp** target (under TARGETS)
3. Click **General** tab
4. Scroll to **"Frameworks, Libraries, and Embedded Content"**
5. Click **"+"** button
6. Click **"Add Other..."** > **"Add Package Dependency..."**
7. Click **"Add Local..."** at bottom left
8. Navigate to the **current directory** (you should already be there)
   - Path: `/Users/baysideuser/GitRepos/AIRoadTripTours`
   - You should see Package.swift in this folder
9. Click **"Add Package"**
10. In "Choose Package Products":
    - Check **AIRoadTripToursApp**
11. Click **"Add Package"**

Xcode will resolve dependencies and link the package.

### 7. Verify Structure

Your project should now look like:

**In Finder**:
```
AIRoadTripTours/
├── AIRoadTripToursIOSApp.xcodeproj     ← Xcode project
├── AIRoadTripToursIOSApp/              ← App source folder
│   ├── AIRoadTripToursIOSAppApp.swift  ← Entry point
│   └── Assets.xcassets                 ← Assets catalog
├── Package.swift                        ← Swift package
├── Sources/                             ← Package sources
└── Tests/                               ← Package tests
```

**In Xcode Project Navigator**:
```
▼ AIRoadTripToursIOSApp
  ▼ AIRoadTripToursIOSApp
    - AIRoadTripToursIOSAppApp.swift
    - Assets.xcassets
  ▼ Package Dependencies
    ▼ AIRoadTripTours
      - AIRoadTripToursCore
      - AIRoadTripToursServices
      - AIRoadTripToursApp
```

### 8. Build and Run

1. Select **iPhone 17** (or any iPhone) simulator from device menu
2. Press **⌘B** to build
   - Should build successfully (~5-10 seconds first time)
3. Press **⌘R** to run
   - App should launch in simulator
   - Onboarding screen should appear

### 9. Test the App

Follow `TESTING_GUIDE.md` for complete testing instructions.

**Quick smoke test**:
- Complete onboarding flow
- Navigate through all 5 tabs
- Verify no crashes

## Final Project Structure

```
AIRoadTripTours/
├── .git/                               Git repository
├── .gitignore
├── Package.swift                       Swift package manifest
├── Package.resolved
├── README.md
├── TESTING_GUIDE.md
├── PHASE_5_BACKEND.md
├── PRODUCTION_APP.md
├── PROJECT_STATUS.md
│
├── Sources/                            Package source code
│   ├── AIRoadTripToursCore/           (Business logic)
│   ├── AIRoadTripToursServices/       (Platform services)
│   ├── AIRoadTripToursApp/            (SwiftUI views)
│   └── AIRoadTripToursDemo/           (CLI demo)
│
├── Tests/                              Package tests
│   ├── AIRoadTripToursCoreTests/
│   └── AIRoadTripToursServicesTests/
│
├── AIRoadTripToursIOSApp.xcodeproj/   iOS app project file
└── AIRoadTripToursIOSApp/             iOS app source code
    ├── AIRoadTripToursIOSAppApp.swift (Entry point)
    └── Assets.xcassets                (Images, colors, etc.)
```

## Benefits of This Structure

✅ **Clean separation**: Package and app at same level
✅ **Single source of truth**: One location for everything
✅ **Easy navigation**: No nested confusion
✅ **Standard practice**: Matches typical iOS + SPM projects
✅ **Git friendly**: Clear .gitignore boundaries

## Next Steps

After creating the project:
1. Build and run the app
2. Test all features using `TESTING_GUIDE.md`
3. Document any issues found
4. Review Phase 5 plan
5. Begin backend integration

## Troubleshooting

**"Cannot find AIRoadTripToursApp"**
- Make sure you added the package dependency in step 6
- Verify "Package Dependencies" shows in Project Navigator
- Clean build folder (⌘⇧K) and rebuild

**Build fails**
- Clean derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Quit Xcode, reopen, and rebuild

**Package doesn't appear when adding dependency**
- Make sure you're in `/Users/baysideuser/GitRepos/AIRoadTripTours`
- This folder should contain `Package.swift`
- Try "Add Local" instead of searching

**Wrong directory structure**
- Delete the project and start over
- Make sure to save in `/Users/baysideuser/GitRepos/AIRoadTripTours` (no subfolders)
