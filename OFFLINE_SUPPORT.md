# Offline Support for Mountain Touring

Complete offline support has been implemented for the AI Road Trip Tours app, enabling users to tour in remote mountain areas without cell service.

## Overview

The offline support system provides:
- **Pre-generated audio narrations** cached locally for all tour POIs
- **Offline map tiles** covering the tour route with buffer
- **Complete tour data persistence** in Documents directory
- **Network connectivity monitoring** for smart sync
- **Background download management** with progress tracking

All data persists locally across app restarts and is stored in the Documents directory for permanent retention.

## Architecture

### Core Components

#### 1. OfflineTourPackage Model
Bundles all data needed for offline touring:
- AudioTourRoute with waypoints and segments
- Audio files for all narration phases (approaching, detailed, guided tour)
- Map tiles at multiple zoom levels (12-16)
- Package metadata (size, creation date, expiration)

**File**: `Sources/AIRoadTripToursCore/Models/OfflineTourPackage.swift`

#### 2. AudioCacheStorage
Manages pre-generated audio file caching:
- Stores audio in Documents/AudioCache/{tourId}/
- Supports MP3, AAC, and Opus formats
- Automatic cache size management (500 MB default)
- Cleanup of expired audio files (30 days)

**File**: `Sources/AIRoadTripToursServices/AudioCacheStorage.swift`

#### 3. OfflineTourPackageStorage
Persistent storage for complete tour packages:
- Stores packages in Documents/OfflineTours/{packageId}/
- Metadata tracking with UserDefaults
- Download status and progress persistence
- Storage statistics and cleanup utilities

**File**: `Sources/AIRoadTripToursServices/OfflineTourPackageStorage.swift`

#### 4. NetworkConnectivityMonitor
Real-time network status tracking:
- WiFi, cellular, wired connection detection
- Suitable-for-download checking (WiFi-only option)
- ObservableObject for reactive UI updates

**File**: `Sources/AIRoadTripToursServices/NetworkConnectivityMonitor.swift`

#### 5. OfflineTourDownloadManager
Orchestrates complete package downloads:
- Three-phase download (audio, maps, bundling)
- Progress tracking per phase
- Error handling and retry logic
- Background task management

**File**: `Sources/AIRoadTripToursServices/OfflineTourDownloadManager.swift`

#### 6. GoogleCloudTTSService
AI audio generation for narrations:
- Free tier: 1 million characters/month (WaveNet voices)
- Multiple voice options (male, female, neutral)
- Automatic text chunking for long narrations
- Speech rate and pitch controls

**File**: `Sources/AIRoadTripToursServices/GoogleCloudTTSService.swift`

#### 7. OfflineDownloadsView
User interface for managing offline content:
- Network status display
- Active download progress cards
- Tour list with download/delete actions
- Storage statistics view

**File**: `Sources/AIRoadTripToursApp/OfflineDownloadsView.swift`

## Usage

### Accessing Offline Downloads

From the Tours tab, tap the download button (arrow.down.circle) in the top-left toolbar to access the Offline Downloads view.

### Downloading a Tour for Offline Use

1. Navigate to Offline Downloads view
2. Ensure WiFi connection (required by default)
3. Find the tour to download in "Available Tours" section
4. Tap the download button (arrow.down.circle)
5. Monitor progress in "Active Downloads" section
6. Wait for download to complete (green checkmark when done)

### Using Offline Tours

Tours downloaded for offline use work seamlessly:
- Audio narrations play from cached files
- Maps display from cached tiles
- POI data loaded from local storage
- No network connection required

### Deleting Offline Packages

1. Open Offline Downloads view
2. Find downloaded tour in list
3. Tap trash icon to delete
4. Confirm deletion

### Monitoring Storage

1. Open Offline Downloads view
2. Tap "Storage Usage"
3. View statistics:
   - Total packages count
   - Total storage size
   - Downloaded, failed, expired counts
4. Use "Clear Expired Packages" to free space
5. Use "Clear All Offline Data" for complete reset

## Implementation Details

### Data Persistence

All offline data is stored in the Documents directory for permanent retention:

```txt
Documents/
├── AudioCache/
│   └── {tourId}/
│       ├── {poiId}_Approaching.m4a
│       ├── {poiId}_Detailed.m4a
│       └── {poiId}_Guided Tour.m4a
└── OfflineTours/
    └── {packageId}/
        └── package.json
```

### Audio File Naming

Audio files use the format: `{poiId}_{phase}.{extension}`

Supported formats:
- AAC (`.m4a`) - recommended, 128 kbps
- MP3 (`.mp3`) - 192 kbps
- Opus (`.opus`) - 96 kbps

### Map Tile Coverage

Map tiles are downloaded for:
- Zoom levels 12-16 (optimal for road trips)
- Bounding box covering entire route
- 5-mile buffer around route
- Estimated 15 KB per tile

### Download Progress

Downloads proceed in three phases:

1. **Audio Download (70% of progress)**: Generate and cache audio for all POIs and narration phases
2. **Map Download (25% of progress)**: Download map tiles covering route bounding box
3. **Bundling (5% of progress)**: Package metadata and finalize storage

### Network Requirements

Downloads require WiFi by default to avoid cellular data charges:
- WiFi: Full download capability
- Cellular: Blocked by default (configurable)
- Wired: Full download capability
- Offline: Downloads blocked

Override with `requireWifi: false` parameter if cellular download acceptable.

### Package Expiration

Offline packages expire after 90 days to ensure data freshness:
- Expired packages marked in storage
- Automatic cleanup available
- Re-download updates content

### Error Handling

Download errors are captured and displayed:
- `networkUnavailable`: No suitable connection
- `alreadyDownloading`: Duplicate download attempt
- `alreadyDownloaded`: Package already cached
- `audioGenerationFailed`: TTS service error
- `mapDownloadFailed`: Map tile download error
- `storageFailed`: Disk write error

## Integration with AppState

Offline support services are initialized in AppState:

```swift
public let audioCache: AudioCacheStorage
public let offlinePackageStorage: OfflineTourPackageStorage
public let networkMonitor: NetworkConnectivityMonitor
public let offlineDownloadManager: OfflineTourDownloadManager
```

All services persist across app lifecycle and are available throughout the app.

## Google Cloud TTS Setup

To use AI-generated audio narrations:

1. Create Google Cloud project
2. Enable Text-to-Speech API
3. Create API key
4. Set environment variable or pass to initializer:
   ```swift
   let ttsService = GoogleCloudTTSService(apiKey: "YOUR_API_KEY")
   ```

### Free Tier Limits

Google Cloud TTS free tier provides:
- 1 million characters/month (WaveNet/Neural2 voices)
- 4 million characters/month (Standard voices)
- Sufficient for ~200 tour downloads per month

### Voice Options

Available voices:
- `VoiceConfig.defaultVoice`: US English female (Neural2-F)
- `VoiceConfig.maleVoice`: US English male (Neural2-D)
- Custom voices with language code and name

### Audio Quality

Narrations use:
- 128 kbps AAC encoding (recommended)
- Speaking rate: 1.0x (adjustable 0.25-4.0x)
- Pitch: 0.0 (adjustable -20.0 to +20.0)

## Performance Considerations

### Initial Download Time

Estimated download times (WiFi, ~10 Mbps):
- Small tour (5 POIs, 20 miles): 2-3 minutes
- Medium tour (10 POIs, 50 miles): 5-7 minutes
- Large tour (20 POIs, 100 miles): 10-15 minutes

### Storage Requirements

Estimated storage per tour:
- Audio files: ~500 KB per POI (3 phases × ~165 KB)
- Map tiles: ~15 KB × tile count (varies by route length)
- Tour metadata: ~50 KB
- **Total**: 5-50 MB per tour depending on size

### Cache Management

Automatic cache management:
- Maximum cache size: 500 MB (configurable)
- LRU eviction when limit exceeded
- Expired package cleanup (30+ days old)
- Manual cleanup available in UI

## Future Enhancements

Potential improvements for offline support:

1. **Incremental Downloads**: Download narrations on-demand during tour
2. **Background Downloads**: Continue downloads when app backgrounded
3. **Delta Updates**: Update only changed content
4. **Compression**: Reduce package size with compression
5. **Prioritized Downloads**: Download nearby POIs first
6. **Offline Route Planning**: Generate routes without network
7. **Peer-to-Peer Sharing**: Share tours via AirDrop
8. **Smart Prefetch**: Auto-download tours along planned routes

## Troubleshooting

### Package Download Fails

Check:
- WiFi connection active
- Sufficient storage available (Settings → General → Storage)
- Google Cloud TTS API key valid
- Tour data complete and valid

### Audio Playback Issues

Verify:
- Audio files exist in Documents/AudioCache/{tourId}/
- File permissions correct
- iOS audio session configured
- Speaker/headphones connected

### Map Display Issues

Confirm:
- Map tiles downloaded successfully
- Bounding box covers current location
- MapKit initialized properly
- Location permissions granted

### Storage Cleanup Not Working

Try:
- Force quit and restart app
- Check file system permissions
- Verify Documents directory accessible
- Use "Clear All Offline Data" for reset

## API Reference

### OfflineTourDownloadManager

```swift
class OfflineTourDownloadManager: ObservableObject {
    func downloadTourPackage(route: AudioTourRoute, requireWifi: Bool) async throws
    func cancelDownload(tourId: UUID)
    func deleteOfflinePackage(tourId: UUID) throws
}
```

### AudioCacheStorage

```swift
class AudioCacheStorage {
    func cacheAudio(_ audioData: Data, tourId: UUID, poiId: UUID, phase: NarrationPhase, format: AudioFormat) throws -> AudioFile
    func getCachedAudio(tourId: UUID, poiId: UUID, phase: NarrationPhase) -> AudioFile?
    func deleteTourCache(tourId: UUID) throws
    func calculateCacheSize() throws -> Int64
}
```

### OfflineTourPackageStorage

```swift
class OfflineTourPackageStorage {
    func savePackage(_ package: OfflineTourPackage) throws
    func loadPackage(id: UUID) throws -> OfflineTourPackage?
    func deletePackage(id: UUID) throws
    func getStatistics() throws -> StorageStatistics
}
```

### NetworkConnectivityMonitor

```swift
class NetworkConnectivityMonitor: ObservableObject {
    @Published var isConnected: Bool
    @Published var connectionType: ConnectionType
    func isSuitableForDownloading(requireWifi: Bool) -> Bool
}
```

## Testing

Test offline functionality:

1. **Enable Airplane Mode**: Settings → Airplane Mode → On
2. **Launch App**: Verify offline tours still accessible
3. **Play Audio**: Confirm narrations play from cache
4. **View Maps**: Ensure map tiles display properly
5. **Navigate Tour**: Test full tour experience offline

For development testing, use simulator:
1. Debug → Simulate Location → Custom Location
2. Set location along tour route
3. Test narration triggers and proximity detection

## Conclusion

The offline support system provides complete functionality for mountain touring without cell service. All data persists locally, downloads are managed intelligently, and the user experience is seamless whether online or offline.

Key benefits:
- **Reliability**: Tour anywhere without network dependency
- **Performance**: Faster audio playback from local cache
- **Cost Savings**: No cellular data usage for downloads
- **Privacy**: All data stored locally on device
