import SwiftUI
import AVKit
import AVFoundation

/// Launch screen with animated video.
public struct LaunchScreenView: View {
    @State private var player: AVPlayer?

    public init() {}

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let player = player {
                VideoPlayerView(player: player)
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

            let asset = AVAsset(url: videoURL)
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            player.isMuted = true
            player.actionAtItemEnd = .pause

            // Preload the player
            player.seek(to: .zero)

            self.player = player

            // Start playback after a brief delay to ensure view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("LaunchScreenView: Starting playback")
                player.play()
            }
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

/// Custom video player view using AVPlayerLayer for better control
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = UIScreen.main.bounds

        view.layer.addSublayer(playerLayer)
        context.coordinator.playerLayer = playerLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}

#Preview {
    LaunchScreenView()
}
