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
                if isAppReady {
                    ContentView()
                        .environment(appState)
                        .onAppear {
                            setupCarPlay()
                            print("ContentView appeared")
                        }
                } else {
                    // Show loading placeholder while app initializes
                    Color.black.ignoresSafeArea()
                }

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

        // Simulate/perform any heavy initialization here
        // The AppState init is already called, but we can do additional setup
        try? await Task.sleep(for: .seconds(1)) // Minimum time to ensure smooth experience

        print("App initialization completed in \(Date().timeIntervalSince(startTime)) seconds")

        // Mark app as ready
        await MainActor.run {
            isAppReady = true
        }

        // Keep launch screen visible for at least 10 seconds total
        let elapsedTime = Date().timeIntervalSince(startTime)
        let remainingTime = max(0, 10.0 - elapsedTime)

        if remainingTime > 0 {
            print("Waiting \(remainingTime) more seconds for minimum launch screen duration...")
            try? await Task.sleep(for: .seconds(remainingTime))
        }

        // Dismiss launch screen with animation
        await MainActor.run {
            print("Dismissing launch screen")
            withAnimation(.easeOut(duration: 0.8)) {
                showLaunchScreen = false
            }
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
