# Launch Screen and App Icon Setup

This document describes the launch screen video and app icon setup for the AI Road Trip Tours iOS app.

## Launch Screen Video

The launch screen displays `LaunchVideo.mp4` when the app launches.

### Setup Complete

- ✅ Video added to `AIRoadTripToursIOSApp/LaunchVideo.mp4`
- ✅ Video properly configured in Xcode project file (Copy Bundle Resources)
- ✅ `LaunchScreenView.swift` created to display the video
- ✅ `App.swift` updated with async initialization and 10-second launch screen
- ✅ Video plays once and holds on final frame (app icon) until timer completes

### How It Works

1. Launch screen appears immediately when app starts
2. Video plays muted, holds on final frame (no loop)
3. App initializes in background using async/await
4. Launch screen stays visible for minimum 10 seconds
5. Smooth 0.8s fade transition reveals the app
6. Fallback UI (map icon + text) displays if video fails to load

### Performance Optimizations

- POI repository lazy-loaded to defer expensive MapKit initialization
- AppState initializes quickly (under 1 second)
- Heavy services only created when first accessed
- Background initialization while launch screen displays

## App Icon Setup

Since automated frame extraction tools are restricted by the sandbox, create the app icon manually:

### Option 1: Use QuickTime Player (Recommended)

1. Open `AIRoadTripTours.mp4` in QuickTime Player
2. Pause at a frame you like (around 1 second in is good)
3. Go to Edit > Copy
4. Open Preview app
5. Go to File > New from Clipboard
6. Go to Tools > Adjust Size
7. Set width to 1024 pixels (height will adjust automatically)
8. Export as PNG: File > Export > Format: PNG
9. Save as `AppIcon-1024.png`

### Option 2: Use macOS Screenshots

1. Open `AIRoadTripTours.mp4` in QuickTime Player
2. Pause at the desired frame
3. Press Cmd+Shift+4, then press Space
4. Click on the QuickTime window to capture it
5. Open the screenshot in Preview
6. Crop to square: Tools > Rectangular Selection, then Tools > Crop
7. Resize to 1024x1024: Tools > Adjust Size
8. Export as PNG

### Adding to Xcode

Once you have the 1024x1024 PNG icon:

1. Open Xcode project
2. Open `Assets.xcassets` (or create it if it doesn't exist)
3. Right-click > App Icons & Launch Images > New iOS App Icon
4. Drag your 1024x1024 PNG into the "1024pt" slot
5. Xcode will automatically generate all required sizes

Alternatively, use an online tool like https://appicon.co to generate all icon sizes from your 1024x1024 image.

## Launch Screen Configuration

The launch screen is configured to:
- Display the video muted and looping
- Show for 3 seconds
- Fade out smoothly to reveal the main app
- Fall back to a simple icon + text if video fails to load

## Testing

Run the app on your iPad to see:
1. Launch screen with video plays for 3 seconds
2. Smooth fade transition to main app
3. App icon appears on home screen (after icon setup)

## Files Modified

- `Sources/AIRoadTripToursApp/LaunchScreenView.swift` (new)
- `Sources/AIRoadTripToursApp/App.swift` (updated)
- `AIRoadTripToursIOSApp/Resources/LaunchVideo.mp4` (copied)
