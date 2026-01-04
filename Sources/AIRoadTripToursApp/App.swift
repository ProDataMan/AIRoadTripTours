import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

/// Main iOS app structure.
public struct AIRoadTripApp: App {
    @State private var appState = AppState()

    public init() {
        print("AIRoadTripApp: Initializing")
    }

    public var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear {
                    print("ContentView appeared")
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
