# App Icon Setup Guide

## Current Status
You have `AIRoadTripToursAppIcon.png` in the project, but it needs to be properly configured in Xcode's asset catalog.

## Quick Fix: Use Icon Generator Website

### Step 1: Generate All Icon Sizes
1. Go to https://www.appicon.co/ or https://appicon.build/
2. Upload your `AIRoadTripToursAppIcon.png` (or extract a frame from the upscaled video)
3. Select **iOS** as the platform
4. Click **Generate**
5. Download the generated zip file

### Step 2: Add to Xcode
1. Open `AIRoadTripToursIOSApp.xcodeproj` in Xcode
2. In Project Navigator, look for `Assets.xcassets`
   - If it doesn't exist: Right-click project → New File → Asset Catalog → Name it "Assets"
3. In Assets.xcassets, look for "AppIcon"
   - If it doesn't exist: Right-click in asset list → App Icons & Launch Images → New iOS App Icon
4. Extract the downloaded zip file
5. Drag the icon files from the extracted folder into the corresponding slots in the AppIcon asset
   - The generator creates files named like `Icon-60@2x.png`, `Icon-60@3x.png`, etc.
   - Match them to the slots by size (Xcode shows required sizes like "60pt @2x")

### Step 3: Verify in Project Settings
1. Select your project in Project Navigator (top item)
2. Select the "AIRoadTripToursIOSApp" target
3. Go to "General" tab
4. Under "App Icons and Launch Screen" → "App Icon Source"
5. Make sure it's set to "AppIcon" (from Assets.xcassets)

### Step 4: Clean and Rebuild
1. Product → Clean Build Folder (Cmd+Shift+K)
2. Build and run on your iPad
3. The icon should now appear on the home screen

## Alternative: Manual Setup in Xcode

If you want to do it manually with just the 1024x1024 image:

1. Create Assets.xcassets in Xcode (if not exists)
2. Add AppIcon asset
3. Drag your 1024x1024 PNG into the "App Store iOS" slot (1024pt)
4. Xcode can sometimes generate other sizes from the 1024pt image, but this is not guaranteed

## Troubleshooting

### Icon not updating on device
- Delete the app from your iPad completely
- Clean build folder in Xcode (Cmd+Shift+K)
- Rebuild and reinstall

### Generic icon still showing
- Verify Assets.xcassets is in the project navigator
- Verify AppIcon asset exists in Assets.xcassets
- Check project settings that "App Icon Source" is set correctly
- Make sure Assets.xcassets is included in "Copy Bundle Resources" build phase

### Icon appears blurry
- Ensure you're using the upscaled video to extract a high-resolution frame
- Make sure the 1024x1024 source image is sharp and high quality

## Required Icon Sizes for iOS

For reference, iOS requires these icon sizes:
- 20pt: @2x (40px), @3x (60px)
- 29pt: @2x (58px), @3x (87px)
- 40pt: @2x (80px), @3x (120px)
- 60pt: @2x (120px), @3x (180px)
- 76pt: @2x (152px) - iPad
- 83.5pt: @2x (167px) - iPad Pro
- 1024pt: @1x (1024px) - App Store

An icon generator website handles all of these automatically.
