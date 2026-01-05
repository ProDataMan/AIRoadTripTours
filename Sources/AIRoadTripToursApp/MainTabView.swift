import SwiftUI

public struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "map")
                }
                .tag(0)

            CommunityToursView()
                .tabItem {
                    Label("Community", systemImage: "person.3")
                }
                .tag(1)

            AudioTourView()
                .tabItem {
                    Label("Audio Tour", systemImage: "speaker.wave.3")
                }
                .tag(2)

            TourHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(3)

            ToursView()
                .tabItem {
                    Label("Tours", systemImage: "map.fill")
                }
                .tag(4)

            RangeCalculatorView()
                .tabItem {
                    Label("Range", systemImage: "bolt.fill")
                }
                .tag(5)

            EnhancedProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(6)
        }
        .environment(\.selectedTab, $selectedTab)
    }
}

// Environment key for tab selection
struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: Binding<Int> = .constant(0)
}

extension EnvironmentValues {
    var selectedTab: Binding<Int> {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
