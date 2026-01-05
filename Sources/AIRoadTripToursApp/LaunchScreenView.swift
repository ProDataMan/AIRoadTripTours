import SwiftUI
import AVKit
import AVFoundation

/// Launch screen with video.
public struct LaunchScreenView: View {
    @State private var player: AVPlayer?

    public init() {}

    public var body: some View {
        ZStack {
            // Dark background to match video (visible in landscape letterboxing)
            Color(red: 0.1, green: 0.1, blue: 0.1)
                .ignoresSafeArea()

            // Video player
            if let player = player {
                #if os(iOS)
                VideoPlayer(player: player) {
                    // No controls
                }
                .disabled(true)
                .ignoresSafeArea()
                #else
                // macOS fallback - show static content
                VStack(spacing: 30) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("AI Road Trip Tours")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                #endif
            } else {
                // Fallback while video loads
                VStack(spacing: 30) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("AI Road Trip Tours")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            setupVideo()
        }
    }

    private func setupVideo() {
        guard let videoURL = Bundle.main.url(forResource: "LaunchVideo", withExtension: "mp4") else {
            print("Launch video not found in bundle")
            return
        }

        print("Launch video found at: \(videoURL)")

        let player = AVPlayer(url: videoURL)
        player.actionAtItemEnd = .pause  // Hold on last frame

        self.player = player
        player.play()
    }
}

#Preview {
    LaunchScreenView()
}
