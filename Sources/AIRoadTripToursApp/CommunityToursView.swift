import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

/// View for browsing community-shared tours.
public struct CommunityToursView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var locationService = LocationService()

    @State private var tours: [SharedTour] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var sortOption: TourSortOption = .popularity
    @State private var selectedTour: SharedTour?
    @State private var showingTourDetail = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sort options
                Picker("Sort By", selection: $sortOption) {
                    ForEach(TourSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if isLoading {
                    ProgressView("Loading tours...")
                        .padding()
                } else if filteredTours.isEmpty {
                    ContentUnavailableView {
                        Label("No Tours Found", systemImage: "map")
                    } description: {
                        Text(searchText.isEmpty ?
                             "Check back later for community-shared tours" :
                             "Try a different search term")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredTours) { tour in
                                CommunityTourCard(tour: tour)
                                    .onTapGesture {
                                        selectedTour = tour
                                        showingTourDetail = true
                                        Task {
                                            await appState.communityTourRepository.recordView(tourId: tour.id)
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Community Tours")
            .searchable(text: $searchText, prompt: "Search tours")
            .task {
                await loadTours()
            }
            .onChange(of: sortOption) { _, _ in
                Task {
                    await loadTours()
                }
            }
            .sheet(isPresented: $showingTourDetail) {
                if let tour = selectedTour {
                    CommunityTourDetailView(tour: tour)
                }
            }
        }
    }

    private var filteredTours: [SharedTour] {
        if searchText.isEmpty {
            return tours
        } else {
            return tours.filter { tour in
                tour.title.localizedCaseInsensitiveContains(searchText) ||
                tour.description.localizedCaseInsensitiveContains(searchText) ||
                tour.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }

    private func loadTours() async {
        isLoading = true
        defer { isLoading = false }

        if searchText.isEmpty {
            tours = await appState.communityTourRepository.getAllTours(
                limit: 50,
                sortBy: sortOption
            )
        } else {
            tours = await appState.communityTourRepository.searchTours(
                query: searchText,
                limit: 50
            )
        }
    }
}

/// Card displaying a community tour summary.
struct CommunityTourCard: View {
    let tour: SharedTour

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tour.title)
                        .font(.headline)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "person.circle")
                            .font(.caption)
                        Text(tour.creatorName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Rating badge
                if tour.metrics.ratingCount > 0 {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", tour.metrics.averageRating))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Text("(\(tour.metrics.ratingCount))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Description
            Text(tour.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Stats
            HStack(spacing: 16) {
                StatBadge(icon: "map", value: "\(tour.pois.count) POIs")
                StatBadge(icon: "arrow.left.and.right",
                         value: String(format: "%.0f mi", tour.totalDistance))
                StatBadge(icon: "clock",
                         value: formatDuration(tour.estimatedDuration))

                if tour.difficulty != .moderate {
                    Spacer()
                    DifficultyBadge(difficulty: tour.difficulty)
                }
            }

            // Tags
            if !tour.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(tour.tags.prefix(5)), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .cornerRadius(8)
                    }
                }
            }

            // Badges
            HStack(spacing: 8) {
                if tour.isFeatured {
                    Badge(text: "Featured", color: .purple)
                }
                if tour.isCurated {
                    Badge(text: "Curated", color: .green)
                }
                if tour.isAutoShared {
                    Badge(text: "Community Pick", color: .orange)
                }

                Spacer()

                // Engagement stats
                HStack(spacing: 12) {
                    EngagementStat(icon: "eye", count: tour.metrics.viewCount)
                    EngagementStat(icon: "checkmark.circle", count: tour.metrics.completionCount)
                    EngagementStat(icon: "bookmark", count: tour.metrics.saveCount)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func formatDuration(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }
}

/// Stat badge component.
struct StatBadge: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

/// Difficulty badge.
struct DifficultyBadge: View {
    let difficulty: TourDifficulty

    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(8)
    }

    private var color: Color {
        switch difficulty {
        case .easy: return .green
        case .moderate: return .orange
        case .challenging: return .red
        }
    }
}

/// General badge component.
struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundStyle(color)
        .cornerRadius(8)
    }
}

/// Engagement statistic display.
struct EngagementStat: View {
    let icon: String
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text("\(count)")
        }
    }
}

#Preview {
    CommunityToursView()
        .environment(AppState())
}
