import SwiftUI

public struct ContentView: View {
    @Environment(AppState.self) private var appState

    public init() {
        print("ContentView: Initializing")
    }

    public var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            print("ContentView: Body appeared, hasCompletedOnboarding = \(appState.hasCompletedOnboarding)")
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
