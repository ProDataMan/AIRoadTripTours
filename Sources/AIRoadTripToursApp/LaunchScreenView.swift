import SwiftUI

/// Launch screen with static app icon.
public struct LaunchScreenView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Static app icon for now - video playback is blocking
            VStack(spacing: 20) {
                Image(systemName: "car.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.blue)

                Text("AI Road Trip Tours")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            print("LaunchScreenView: Appeared")
        }
    }
}

#Preview {
    LaunchScreenView()
}
