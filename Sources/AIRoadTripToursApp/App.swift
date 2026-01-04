import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

/// Main iOS app structure.
public struct AIRoadTripApp: App {
    @State private var appState = AppState()
    @State private var showLaunchScreen = true

    public init() {
        print("AIRoadTripApp: Initializing")
    }

    public var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app - always rendered
                ContentView()
                    .environment(appState)
                    .onAppear {
                        print("ContentView appeared")
                        // Dismiss launch screen after brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.easeOut(duration: 0.8)) {
                                showLaunchScreen = false
                            }
                        }
                    }

                // Launch screen overlay
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
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
