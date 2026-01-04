import SwiftUI

/// Launch screen with app branding.
public struct LaunchScreenView: View {
    public init() {}

    public var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()

            // App branding
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
}

#Preview {
    LaunchScreenView()
}
