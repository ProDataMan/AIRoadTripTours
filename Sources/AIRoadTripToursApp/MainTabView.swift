import SwiftUI

public struct MainTabView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        TabView {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "map")
                }

            CommunityToursView()
                .tabItem {
                    Label("Community", systemImage: "person.3")
                }

            AudioTourView()
                .tabItem {
                    Label("Audio Tour", systemImage: "speaker.wave.3")
                }

            TourHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }

            ToursView()
                .tabItem {
                    Label("Tours", systemImage: "map.fill")
                }

            RangeCalculatorView()
                .tabItem {
                    Label("Range", systemImage: "bolt.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
