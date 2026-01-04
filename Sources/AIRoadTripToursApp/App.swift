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
    @State private var showLaunchScreen = true

    #if canImport(CarPlay)
    @available(iOS 14.0, *)
    private static var carPlaySceneDelegate = CarPlaySceneDelegate()
    #endif

    public init() {}

    public var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(appState)
                    .onAppear {
                        setupCarPlay()
                    }

                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    showLaunchScreen = false
                                }
                            }
                        }
                }
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
