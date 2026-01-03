# CarPlay Integration Guide

This guide explains how to enable CarPlay support in your AI Road Trip Tours iOS app.

## Overview

CarPlay integration provides a driver-safe interface for audio tours directly on the car's display. Features include:

- Browse nearby points of interest
- Select and start audio tours
- View active tour with map
- Control audio playback with physical and voice controls
- Automatic now playing integration

## Prerequisites

- iOS 14.0 or later
- CarPlay-enabled vehicle or CarPlay simulator
- Apple Developer account with CarPlay entitlement

## Setup Instructions

### 1. Request CarPlay Entitlement

Contact Apple to request the CarPlay entitlement for your app:
1. Sign in to your Apple Developer account
2. Navigate to Certificates, Identifiers & Profiles
3. Request CarPlay App entitlement
4. Provide justification for your audio navigation app

### 2. Configure Xcode Project

Add the CarPlay entitlement to your Xcode project:

1. Select your app target
2. Go to Signing & Capabilities
3. Click + Capability
4. Add "CarPlay" capability
5. Select "Audio" as the app category

### 3. Update Info.plist

Add CarPlay scene configuration to your Info.plist:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <true/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>CPTemplateApplicationSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneClassName</key>
                <string>CPTemplateApplicationScene</string>
                <key>UISceneConfigurationName</key>
                <string>CarPlay</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

### 4. Add Background Modes

Enable audio background mode in Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

This is already configured in the NarrationAudio service for background audio playback.

## CarPlay Features

### Discover Tab

Browse nearby points of interest based on current location:
- Shows up to 12 nearest POIs
- Tap to select/deselect POIs for tour
- Updates dynamically as location changes

### Tours Tab

Manage and start audio tours:
- View active tour if one is running
- Start quick tour with selected POIs
- Shows POI count and status

### Now Playing Tab

Control audio playback:
- Play/Pause/Skip controls
- POI information display
- Progress tracking
- Integrated with iOS Now Playing center

### Map View

Visual navigation during tours:
- Shows route to POIs
- Current location tracking
- Turn-by-turn preview

## Testing CarPlay

### Using CarPlay Simulator

1. Run your app in iOS Simulator
2. Open Hardware menu → External Displays → CarPlay
3. The CarPlay window will appear
4. Test navigation and audio features

### Using Physical Device

1. Connect iPhone to CarPlay-enabled vehicle
2. Launch the app
3. App appears in CarPlay dashboard
4. Test with actual driving (parked or with passenger)

## Architecture

### CarPlaySceneDelegate

Manages CarPlay lifecycle and templates:
- Connects to car display
- Creates and updates UI templates
- Handles user interactions
- Syncs with main app state

### Template System

CarPlay uses template-based UI:
- `CPTabBarTemplate`: Main navigation tabs
- `CPListTemplate`: POI and tour lists
- `CPMapTemplate`: Map view during tours
- `CPNowPlayingTemplate`: Audio controls

### Integration Points

CarPlay integrates with existing services:
- `AudioTourManager`: Tour state and playback
- `LocationService`: Current location
- `POIRepository`: Nearby POI discovery
- `NavigationService`: Route information
- `MPNowPlayingInfoCenter`: Now playing display

## Safety Considerations

CarPlay enforces driver safety:
- Limited interaction while driving
- Voice control support
- Large touch targets
- Minimal visual distraction
- Automatic pause when disconnected

## Troubleshooting

### CarPlay Not Appearing

- Verify CarPlay entitlement is approved
- Check Info.plist configuration
- Ensure iOS 14.0+ deployment target
- Restart Xcode and clean build

### Templates Not Loading

- Check scene delegate is properly initialized
- Verify appState is set on CarPlaySceneDelegate
- Review console logs for errors

### Audio Not Playing

- Confirm audio session configuration
- Check background modes are enabled
- Verify MPNowPlayingInfoCenter updates

## Best Practices

1. Keep interactions simple and driver-focused
2. Use clear, concise text in templates
3. Limit list items to essential information
4. Test in actual vehicle when possible
5. Handle disconnection gracefully
6. Support voice commands via Siri

## Limitations

- Maximum 12 tabs in CPTabBarTemplate
- Map interaction limited while driving
- No custom graphics (template-based only)
- Text input not available while driving
- Requires active CarPlay connection

## Resources

- [CarPlay Programming Guide](https://developer.apple.com/carplay/)
- [CarPlay App Programming Guide](https://developer.apple.com/documentation/carplay)
- [Human Interface Guidelines - CarPlay](https://developer.apple.com/design/human-interface-guidelines/carplay)
