import SwiftUI
import AVKit

/// Launch screen with animated video.
public struct LaunchScreenView: View {
    @State private var isActive = false
    @State private var player: AVPlayer?

    public init() {}

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .ignoresSafeArea()
            } else {
                // Fallback if video fails to load
                VStack(spacing: 20) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)

                    Text("AI Road Trip Tours")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
    }

    private func setupPlayer() {
        print("LaunchScreenView: Setting up player...")

        // Try to find the video
        if let videoURL = Bundle.main.url(forResource: "LaunchVideo", withExtension: "mp4") {
            print("LaunchScreenView: Video found at \(videoURL)")

            let player = AVPlayer(url: videoURL)
            player.isMuted = true
            player.play()

            // Loop the video
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }

            self.player = player
        } else {
            print("LaunchScreenView: Video not found in bundle")

            // List all resources to debug
            if let resourcePath = Bundle.main.resourcePath {
                print("LaunchScreenView: Resource path: \(resourcePath)")
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    print("LaunchScreenView: Bundle contents: \(contents.filter { $0.hasSuffix(".mp4") })")
                } catch {
                    print("LaunchScreenView: Error listing bundle contents: \(error)")
                }
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
