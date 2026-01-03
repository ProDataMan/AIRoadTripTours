# AI Road Trip Tours - Audio Tour Setup Guide

Instructions for adding audio narration playback to the iOS app.

## Prerequisites

- iOS app created following IOS_APP_SETUP.md
- AIRoadTripToursCore and AIRoadTripToursServices packages added to project

## Step 1: Add Services Module to iOS App

1. Open your iOS project in Xcode
2. Select the app target
3. Navigate to **General** > **Frameworks, Libraries, and Embedded Content**
4. Click **+** and add **AIRoadTripToursServices** library
5. Ensure it's set to "Do Not Embed"

## Step 2: Configure Audio Session in Info.plist

The audio permissions should already be set if you followed IOS_APP_SETUP.md. Verify these keys exist:

- **Privacy - Microphone Usage Description** (optional, only if recording)
- Audio session is automatically configured by AVSpeechNarrationAudioService

## Step 3: Create Audio Tour View

Create `Views/AudioTourView.swift`:

```swift
import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

struct AudioTourView: View {
    @Environment(AppState.self) private var appState
    @State private var audioService = AVSpeechNarrationAudioService()
    @State private var queue = NarrationQueue()
    @State private var currentNarration: Narration?
    @State private var playbackState: NarrationPlaybackState = .idle
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isGenerating {
                    ProgressView("Generating narrations...")
                        .padding()
                } else {
                    // Playback Controls
                    VStack(spacing: 16) {
                        if let narration = currentNarration {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Now Playing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(narration.poiName)
                                    .font(.title2)
                                    .bold()

                                Text(narration.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(12)
                        }

                        // Playback State
                        HStack(spacing: 12) {
                            Image(systemName: playbackStateIcon)
                                .font(.title2)
                                .foregroundStyle(playbackStateColor)

                            Text(playbackState.rawValue)
                                .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(playbackStateColor.opacity(0.1))
                        .cornerRadius(8)

                        // Control Buttons
                        HStack(spacing: 24) {
                            Button {
                                Task { await handleStop() }
                            } label: {
                                Image(systemName: "stop.fill")
                                    .font(.title)
                                    .frame(width: 60, height: 60)
                                    .background(.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .cornerRadius(30)
                            }
                            .disabled(playbackState == .idle)

                            Button {
                                Task { await handlePlayPause() }
                            } label: {
                                Image(systemName: playPauseIcon)
                                    .font(.title)
                                    .frame(width: 80, height: 80)
                                    .background(.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(40)
                            }

                            Button {
                                Task { await handleSkip() }
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.title)
                                    .frame(width: 60, height: 60)
                                    .background(.gray.opacity(0.1))
                                    .foregroundStyle(.gray)
                                    .cornerRadius(30)
                            }
                            .disabled(playbackState == .idle || playbackState == .completed)
                        }
                        .padding()
                    }

                    Spacer()

                    // Start Tour Button
                    Button {
                        Task { await startAudioTour() }
                    } label: {
                        Label("Start Audio Tour", systemImage: "play.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("Audio Tour")
            .task {
                await monitorPlaybackState()
            }
        }
    }

    private var playbackStateIcon: String {
        switch playbackState {
        case .idle: return "speaker.slash.fill"
        case .preparing: return "hourglass"
        case .playing: return "speaker.wave.3.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var playbackStateColor: Color {
        switch playbackState {
        case .idle: return .gray
        case .preparing: return .orange
        case .playing: return .blue
        case .paused: return .yellow
        case .completed: return .green
        case .failed: return .red
        }
    }

    private var playPauseIcon: String {
        playbackState == .playing ? "pause.fill" : "play.fill"
    }

    private func startAudioTour() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            // Get nearby POIs
            let portland = GeoLocation(latitude: 45.5152, longitude: -122.6784)
            let pois = try await appState.poiRepository.findNearby(
                location: portland,
                radiusMiles: 25.0,
                categories: nil
            )

            // Generate narrations
            let generator = MockContentGenerator()
            var narrations: [Narration] = []

            for poi in pois.prefix(5) {
                let narration = try await generator.generateNarration(
                    for: poi,
                    targetDurationSeconds: 45.0,
                    userInterests: appState.currentUser?.interests ?? []
                )
                narrations.append(narration)
            }

            // Enqueue and start playing
            await queue.enqueue(narrations)
            await playNext()

        } catch {
            print("Error starting audio tour: \(error)")
        }
    }

    private func playNext() async {
        guard let narration = await queue.next() else {
            playbackState = .completed
            currentNarration = nil
            return
        }

        do {
            currentNarration = narration
            await queue.updateStatus(narration.id, status: .playing)
            try await audioService.play(narration)

            // Wait for completion
            try await Task.sleep(for: .seconds(narration.durationSeconds))

            await queue.updateStatus(narration.id, status: .completed)

            // Play next
            await playNext()

        } catch {
            print("Error playing narration: \(error)")
            playbackState = .failed
        }
    }

    private func handlePlayPause() async {
        switch playbackState {
        case .playing:
            await audioService.pause()
        case .paused:
            await audioService.resume()
        case .idle, .completed:
            await playNext()
        case .preparing, .failed:
            break
        }
    }

    private func handleStop() async {
        await audioService.stop()
        await queue.clear()
        currentNarration = nil
        playbackState = .idle
    }

    private func handleSkip() async {
        await audioService.stop()
        if let current = currentNarration {
            await queue.updateStatus(current.id, status: .skipped)
        }
        await playNext()
    }

    private func monitorPlaybackState() async {
        while true {
            playbackState = await audioService.playbackState
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}

#Preview {
    AudioTourView()
        .environment(AppState())
}
```

## Step 4: Add Audio Tour Tab

Update `MainTabView.swift` to include the audio tour tab:

```swift
import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "map")
                }

            AudioTourView()
                .tabItem {
                    Label("Audio Tour", systemImage: "speaker.wave.3")
                }

            ToursView()
                .tabItem {
                    Label("Tours", systemImage: "map.fill")
                }

            RangeCalculatorView()
                .tabItem {
                    Label("Range", systemImage: "bolt.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}
```

## Step 5: Build and Test

1. Select iPhone 15 Pro simulator
2. Press **⌘R** to build and run
3. Complete onboarding if needed
4. Navigate to **Audio Tour** tab
5. Tap **Start Audio Tour**
6. Listen to AI-generated narrations with speech synthesis

## Features Demonstrated

- **Text-to-Speech**: Uses AVSpeechSynthesizer for offline audio
- **Queue Management**: Plays narrations sequentially
- **Playback Controls**: Play, pause, stop, skip
- **State Tracking**: Visual feedback for playback state
- **Integration**: Works with POI discovery and narration generation

## Customization Options

Modify `AudioTourView.swift` to:

- Adjust narration duration (currently 45 seconds)
- Change number of POIs (currently 5)
- Customize voice settings (rate, pitch, volume)
- Add volume controls
- Implement background audio playback
- Add progress indicators

## Voice Selection

To use a specific voice, modify `AVSpeechNarrationAudioService`:

```swift
// In AudioTourView.swift, after creating audioService:
if let voice = AVSpeechSynthesisVoice(language: "en-US") {
    audioService.voice = voice
}

// Adjust speech rate (0.0 = slowest, 1.0 = fastest)
audioService.rate = 0.5

// Adjust pitch (0.5 = lower, 2.0 = higher)
audioService.pitchMultiplier = 1.0

// Adjust volume (0.0 = silent, 1.0 = maximum)
audioService.volume = 1.0
```

## Available Voices

List available voices in your app:

```swift
let voices = AVSpeechSynthesisVoice.speechVoices()
for voice in voices where voice.language.starts(with: "en") {
    print("\(voice.name) - \(voice.language) - Quality: \(voice.quality.rawValue)")
}
```

On iOS 16+, enhanced neural voices provide higher quality:
- `com.apple.voice.enhanced.en-US.Samantha`
- `com.apple.voice.premium.en-US.Zoe`

## Troubleshooting

**No audio playing:**
- Check device volume
- Verify silent mode is off
- Ensure audio session is configured (handled automatically)

**Audio cuts off:**
- App may be entering background - implement background audio

**Poor voice quality:**
- Try enhanced/premium voices on iOS 16+
- Adjust speech rate for clarity

## Next Steps

- Integrate with real-time location for automatic triggering
- Add background audio playback capability
- Implement audio caching for offline use
- Connect to real AI services (Claude API, ElevenLabs)
- Add voice selection UI
