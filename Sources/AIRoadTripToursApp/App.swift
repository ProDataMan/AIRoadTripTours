import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

/// Main iOS app structure.
public struct AIRoadTripApp: App {
    public init() {
        // Load environment variables from .env file
        ServiceConfiguration.loadEnvironment()
    }

    public var body: some Scene {
        WindowGroup {
            LoadingView()
        }
    }
}

struct LoadingView: View {
    @State private var appState: AppState?
    @State private var showLaunchScreen = true

    var body: some View {
        ZStack {
            // Main content
            if let appState = appState {
                ContentView()
                    .environment(appState)
                    .opacity(showLaunchScreen ? 0 : 1)
            }

            // Launch screen - always shows first
            if showLaunchScreen {
                LaunchScreenView()
                    .zIndex(999)
            }
        }
        .onAppear {
            print("LoadingView appeared - starting initialization")

            // Initialize AppState in background
            Task {
                print("Creating AppState...")
                let state = await MainActor.run {
                    AppState()
                }

                await MainActor.run {
                    print("AppState created, assigning...")
                    self.appState = state

                    // Wait 8.5 seconds then dismiss launch screen (6.3s video + 2s pause on last frame)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8.5) {
                        print("Dismissing launch screen")
                        withAnimation(.easeOut(duration: 0.8)) {
                            showLaunchScreen = false
                        }
                    }
                }
            }
        }
    }
}

#if canImport(CarPlay)
/// CarPlay scene for template-based UI
@available(iOS 14.0, *)
public struct CPTemplateApplicationScene: Scene {
    let connectHandler: (CPTemplateApplicationScene) -> Void

    public var body: some Scene {
        WindowGroup {
            EmptyView()
        }
    }

    public init(connectHandler: @escaping (CPTemplateApplicationScene) -> Void) {
        self.connectHandler = connectHandler
    }
}
#endif
