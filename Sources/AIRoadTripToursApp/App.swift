import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

/// Main iOS app structure.
public struct AIRoadTripApp: App {
    @State private var appState: AppState?
    @State private var showLaunchScreen = true

    public init() {
        print("AIRoadTripApp: Initializing")
    }

    public var body: some Scene {
        WindowGroup {
            ZStack {
                // Show launch screen until AppState is ready
                if let appState = appState {
                    // Main app - rendered after AppState loads
                    ContentView()
                        .environment(appState)
                        .onAppear {
                            print("ContentView appeared")
                            // Dismiss launch screen after brief delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    showLaunchScreen = false
                                }
                            }
                        }
                        .opacity(showLaunchScreen ? 0 : 1)
                }

                // Launch screen overlay
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // Initialize AppState in background while launch screen shows
                print("Starting AppState initialization in background...")
                let state = AppState()
                await MainActor.run {
                    self.appState = state
                    print("AppState ready and assigned")
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
