import SwiftUI
import AIRoadTripToursCore
#if canImport(MapKit)
import MapKit
#if canImport(UIKit)
import UIKit
#endif
#endif

/// View displaying tour history and statistics.
public struct TourHistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var recentTours: [TourHistoryEntry] = []
    @State private var statistics: TourStatistics = .empty
    @State private var selectedTour: TourHistoryEntry?
    @State private var showingDeleteConfirmation = false
    @State private var tourToDelete: TourHistoryEntry?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Statistics Summary Card
                    if statistics.totalToursCompleted > 0 {
                        StatisticsSummaryCard(statistics: statistics)
                            .padding(.horizontal)
                    } else {
                        EmptyHistoryView()
                            .padding(.horizontal)
                    }

                    // Recent Tours List
                    if !recentTours.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Tours")
                                    .font(.title2)
                                    .bold()

                                Spacer()

                                if recentTours.count > 10 {
                                    Text("\(recentTours.count) total")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal)

                            ForEach(recentTours) { tour in
                                TourHistoryCard(tour: tour)
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        selectedTour = tour
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            tourToDelete = tour
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.top)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Tour History")
            .toolbar {
                if statistics.totalToursCompleted > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(role: .destructive) {
                                clearAllHistory()
                            } label: {
                                Label("Clear All History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(item: $selectedTour) { tour in
                TourHistoryDetailView(tour: tour)
            }
            .alert("Delete Tour?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let tour = tourToDelete {
                        deleteTour(tour)
                    }
                }
            } message: {
                Text("This tour will be permanently deleted from your history.")
            }
            .task {
                loadHistory()
            }
        }
    }

    private func loadHistory() {
        recentTours = appState.tourHistoryStorage.getRecentHistory(limit: 50)
        statistics = appState.tourHistoryStorage.computeStatistics()
    }

    private func deleteTour(_ tour: TourHistoryEntry) {
        appState.tourHistoryStorage.deleteEntry(tour)
        loadHistory()
    }

    private func clearAllHistory() {
        appState.tourHistoryStorage.clearAll()
        loadHistory()
    }
}

// MARK: - Statistics Summary Card

struct StatisticsSummaryCard: View {
    let statistics: TourStatistics

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Your Statistics")
                    .font(.title2)
                    .bold()
                Spacer()
            }

            Divider()

            // Primary Stats
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatItem(
                    icon: "car.fill",
                    value: "\(statistics.totalToursCompleted)",
                    label: "Tours"
                )

                StatItem(
                    icon: "map.fill",
                    value: String(format: "%.0f mi", statistics.totalDistanceMiles),
                    label: "Distance"
                )

                StatItem(
                    icon: "mappin.circle.fill",
                    value: "\(statistics.totalPOIsVisited)",
                    label: "POIs"
                )

                StatItem(
                    icon: "clock.fill",
                    value: formatTime(statistics.totalTimeMinutes),
                    label: "Time"
                )
            }

            // Records
            if statistics.longestTourMiles > 0 || statistics.mostPOIsInOneTour > 0 {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Records")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("Longest Tour:")
                        Spacer()
                        Text(String(format: "%.1f miles", statistics.longestTourMiles))
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)

                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Most POIs:")
                        Spacer()
                        Text("\(statistics.mostPOIsInOneTour)")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
            }

            // Date range
            if let firstDate = statistics.firstTourDate, statistics.lastTourDate != nil {
                Divider()

                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text("Member since \(formatDate(firstDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Tour History Card

struct TourHistoryCard: View {
    let tour: TourHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tour.tourName)
                        .font(.headline)

                    Text(formatDate(tour.completedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Stats
            HStack(spacing: 20) {
                Label(
                    "\(tour.poisVisited) POIs",
                    systemImage: "mappin.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Label(
                    String(format: "%.1f mi", tour.distanceMiles),
                    systemImage: "map.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Label(
                    formatDuration(tour.durationMinutes),
                    systemImage: "clock.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
}

// MARK: - Tour History Detail View

struct TourHistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let tour: TourHistoryEntry

    @State private var showingShareSheet = false
    @State private var showingRatingSheet = false
    @State private var tourHistory: TourHistory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tour.tourName)
                            .font(.title)
                            .bold()

                        Text(formatDate(tour.completedAt))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Divider()

                        // Stats grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            DetailStatItem(
                                icon: "mappin.circle.fill",
                                label: "POIs Visited",
                                value: "\(tour.poisVisited)"
                            )

                            DetailStatItem(
                                icon: "map.fill",
                                label: "Distance",
                                value: String(format: "%.1f miles", tour.distanceMiles)
                            )

                            DetailStatItem(
                                icon: "clock.fill",
                                label: "Duration",
                                value: formatDuration(tour.durationMinutes)
                            )

                            DetailStatItem(
                                icon: "calendar",
                                label: "Date",
                                value: formatShortDate(tour.completedAt)
                            )
                        }
                    }
                    .padding()

                    // Route map
                    #if os(iOS)
                    if #available(iOS 17.0, *), !tour.routeCoordinates.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Route")
                                .font(.headline)
                                .padding(.horizontal)

                            TourRouteMapView(coordinates: tour.routeCoordinates)
                                .frame(height: 300)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                    #endif
                }
                .padding(.vertical)
            }
            .navigationTitle("Tour Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            if tourHistory != nil {
                                showingShareSheet = true
                            }
                        } label: {
                            Label("Share with Community", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            if tourHistory != nil {
                                showingRatingSheet = true
                            }
                        } label: {
                            Label("Rate This Tour", systemImage: "star")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let history = tourHistory {
                    ShareTourView(tourHistory: history)
                }
            }
            .sheet(isPresented: $showingRatingSheet) {
                if let history = tourHistory {
                    RateTourView(tourHistory: history) { rating in
                        // Rating submitted
                    }
                }
            }
            .task {
                loadTourHistory()
            }
        }
    }

    private func loadTourHistory() {
        // TODO: Implement getTourHistory method in TourHistoryStorage
        // Convert TourHistoryEntry to TourHistory for sharing/rating
        // This would need the actual tour data from storage
        // tourHistory = appState.tourHistoryStorage.getTourHistory(for: tour)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
}

struct DetailStatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Tour Route Map View

#if os(iOS)
@available(iOS 17.0, *)
struct TourRouteMapView: View {
    let coordinates: [GeoLocation]

    private var region: MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 45.5, longitude: -122.6),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.2,
            longitudeDelta: max(maxLon - minLon, 0.01) * 1.2
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        Map(initialPosition: .region(region)) {
            // Draw route polyline
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates.map { coord in
                    CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
                })
                .stroke(.blue, lineWidth: 3)
            }

            // Start marker
            if let first = coordinates.first {
                Annotation("Start", coordinate: CLLocationCoordinate2D(
                    latitude: first.latitude,
                    longitude: first.longitude
                )) {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }
            }

            // End marker
            if let last = coordinates.last, coordinates.count > 1 {
                Annotation("End", coordinate: CLLocationCoordinate2D(
                    latitude: last.latitude,
                    longitude: last.longitude
                )) {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                }
            }
        }
    }
}
#endif

// MARK: - Empty History View

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Tour History")
                .font(.title2)
                .bold()

            Text("Complete an audio tour to see your history and statistics here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }
}

#Preview {
    TourHistoryView()
        .environment(AppState())
}
