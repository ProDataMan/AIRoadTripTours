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
        guard let videoURL = Bundle.main.url(forResource: "LaunchVideo", withExtension: "mp4") else {
            print("Video not found in bundle")
            return
        }

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
    }
}

#Preview {
    LaunchScreenView()
}
