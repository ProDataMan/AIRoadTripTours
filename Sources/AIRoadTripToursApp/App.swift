import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices
#if canImport(CarPlay)
import CarPlay
#endif

/// Main iOS app structure.
///
/// To use this in an Xcode iOS app project:
/// 1. Create a new iOS App in Xcode
/// 2. Add this package as a dependency
/// 3. Import AIRoadTripToursApp in your app file
/// 4. Use AIRoadTripApp as your @main App
/// 5. Add CarPlay entitlement in Xcode project settings
/// 6. Add UIApplicationSceneManifest to Info.plist with CarPlay scene configuration
public struct AIRoadTripApp: App {
    @State private var appState = AppState()
    @State private var showLaunchScreen = true  // Enabled to cover loading time
    @State private var isAppReady = false

    #if canImport(CarPlay)
    @available(iOS 14.0, *)
    private static var carPlaySceneDelegate = CarPlaySceneDelegate()
    #endif

    public init() {}

    public var body: some Scene {
        WindowGroup {
            ZStack {
                // Always show ContentView when ready, even if launch screen is visible
                if isAppReady {
                    ContentView()
                        .environment(appState)
                        .opacity(showLaunchScreen ? 0 : 1)
                        .onAppear {
                            print("ContentView appeared - about to setup CarPlay")
                            // Defer CarPlay setup to avoid blocking main thread
                            Task.detached {
                                await MainActor.run {
                                    setupCarPlay()
                                    print("CarPlay setup completed")
                                }
                            }
                        }
                }

                // Launch screen on top, fades out
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // Initialize app in background while launch screen plays
                await initializeApp()
            }
        }

        #if canImport(CarPlay)
        if #available(iOS 14.0, *) {
            CPTemplateApplicationScene(connectHandler: { scene in
                Self.carPlaySceneDelegate.setAppState(appState)
            })
        }
        #endif
    }

    private func initializeApp() async {
        print("App initialization started...")
        let startTime = Date()

        // Mark app as ready immediately
        await MainActor.run {
            isAppReady = true
            print("App marked as ready")
        }

        print("App initialization completed in \(Date().timeIntervalSince(startTime)) seconds")

        // Keep launch screen visible for 2 seconds
        let elapsedTime = Date().timeIntervalSince(startTime)
        let remainingTime = max(0, 2.0 - elapsedTime)

        if remainingTime > 0 {
            print("Waiting \(remainingTime) more seconds for minimum launch screen duration...")
            try? await Task.sleep(for: .seconds(remainingTime))
        }

        // Dismiss launch screen with animation
        await MainActor.run {
            print("Dismissing launch screen")
            withAnimation(.easeOut(duration: 0.5)) {
                showLaunchScreen = false
            }
            print("Launch screen dismissed, ContentView should be visible")
        }
    }

    private func setupCarPlay() {
        #if canImport(CarPlay)
        if #available(iOS 14.0, *) {
            Self.carPlaySceneDelegate.setAppState(appState)
        }
        #endif
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
