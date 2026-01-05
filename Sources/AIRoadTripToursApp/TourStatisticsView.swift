import SwiftUI
import Charts
import AIRoadTripToursCore

/// Detailed tour statistics and analytics.
public struct TourStatisticsView: View {
    @Environment(AppState.self) private var appState
    @State private var stats: TourStatistics = .empty
    @State private var recentHistory: [TourHistoryEntry] = []
    @State private var showingClearConfirmation = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if stats.totalToursCompleted == 0 {
                        ContentUnavailableView(
                            "No Tour History",
                            systemImage: "map",
                            description: Text("Complete your first tour to see statistics")
                        )
                        .padding(.top, 100)
                    } else {
                        // Overall Statistics Cards
                        overallStatsSection

                        // Achievement Cards
                        achievementsSection

                        // Timeline
                        timelineSection

                        // Tours Over Time Chart
                        if !recentHistory.isEmpty {
                            toursOverTimeChart
                        }

                        // Recent History
                        recentHistorySection
                    }
                }
                .padding()
            }
            .navigationTitle("Tour Statistics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if stats.totalToursCompleted > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(role: .destructive) {
                                showingClearConfirmation = true
                            } label: {
                                Label("Clear History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear All History?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    appState.tourHistoryStorage.clearAll()
                    loadData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all tour history and statistics.")
            }
            .task {
                loadData()
            }
        }
    }

    private var overallStatsSection: some View {
        VStack(spacing: 12) {
            Text("Overall Statistics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    value: "\(stats.totalToursCompleted)",
                    label: "Tours Completed",
                    icon: "map.fill",
                    color: .blue
                )

                StatCard(
                    value: "\(Int(stats.totalDistanceMiles))",
                    label: "Miles Traveled",
                    icon: "road.lanes",
                    color: .green
                )

                StatCard(
                    value: "\(stats.totalPOIsVisited)",
                    label: "POIs Visited",
                    icon: "mappin.circle.fill",
                    color: .orange
                )

                StatCard(
                    value: formatTime(minutes: stats.totalTimeMinutes),
                    label: "Time Touring",
                    icon: "clock.fill",
                    color: .purple
                )
            }
        }
    }

    private var achievementsSection: some View {
        VStack(spacing: 12) {
            Text("Achievements")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                AchievementCard(
                    value: "\(Int(stats.longestTourMiles)) mi",
                    label: "Longest Tour",
                    icon: "road.lanes.curved.right",
                    gradient: [.blue, .cyan]
                )

                AchievementCard(
                    value: "\(stats.mostPOIsInOneTour)",
                    label: "Most POIs",
                    icon: "star.fill",
                    gradient: [.orange, .yellow]
                )
            }
        }
    }

    private var timelineSection: some View {
        VStack(spacing: 12) {
            Text("Timeline")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                if let firstTour = stats.firstTourDate {
                    HStack {
                        Label("First Tour", systemImage: "flag.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Text(firstTour, style: .date)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    #if os(iOS)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    #else
                    .background(Color.gray.opacity(0.1))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let lastTour = stats.lastTourDate {
                    HStack {
                        Label("Latest Tour", systemImage: "clock.fill")
                            .foregroundStyle(.blue)
                        Spacer()
                        Text(lastTour, style: .date)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    #if os(iOS)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    #else
                    .background(Color.gray.opacity(0.1))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let firstTour = stats.firstTourDate, let lastTour = stats.lastTourDate {
                    let days = Calendar.current.dateComponents([.day], from: firstTour, to: lastTour).day ?? 0
                    HStack {
                        Label("Touring Since", systemImage: "calendar")
                            .foregroundStyle(.purple)
                        Spacer()
                        Text("\(days) days")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    #if os(iOS)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    #else
                    .background(Color.gray.opacity(0.1))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    @ViewBuilder
    private var toursOverTimeChart: some View {
        VStack(spacing: 12) {
            Text("Tours Over Time")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Chart {
                ForEach(recentHistory) { entry in
                    BarMark(
                        x: .value("Date", entry.completedAt, unit: .day),
                        y: .value("Tours", 1)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 200)
            .padding()
            #if os(iOS)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            #else
            .background(Color.gray.opacity(0.1))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var recentHistorySection: some View {
        VStack(spacing: 12) {
            Text("Recent Tours")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ForEach(recentHistory.prefix(10)) { entry in
                    TourHistoryRow(entry: entry)
                }
            }
        }
    }

    private func loadData() {
        stats = appState.tourHistoryStorage.computeStatistics()
        recentHistory = appState.tourHistoryStorage.getRecentHistory(limit: 50)
    }

    private func formatTime(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            return "\(hours)h"
        }
    }
}

/// Statistics card with icon.
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Achievement card with gradient.
struct AchievementCard: View {
    let value: String
    let label: String
    let icon: String
    let gradient: [Color]

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Row displaying a tour history entry.
struct TourHistoryRow: View {
    let entry: TourHistoryEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.tourName)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(Int(entry.distanceMiles)) mi", systemImage: "road.lanes")
                    Label("\(entry.poisVisited) POIs", systemImage: "mappin.circle")
                    Label("\(entry.durationMinutes)m", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.completedAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TourStatisticsView()
        .environment(AppState())
}
