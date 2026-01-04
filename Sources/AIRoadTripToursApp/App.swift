import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices
#if canImport(CarPlay)
import CarPlay
#endif

/// Minimal app structure for debugging.
public struct AIRoadTripApp: App {
    public init() {
        print("AIRoadTripApp: Initializing")
    }

    public var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                Text("AI Road Trip Tours")
                    .font(.largeTitle)
                    .bold()

                Text("App is running!")
                    .font(.title2)

                Image(systemName: "car.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }
            .padding()
            .onAppear {
                print("Main view appeared - app is working")
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
