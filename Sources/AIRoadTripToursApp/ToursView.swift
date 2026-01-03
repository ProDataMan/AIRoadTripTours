import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

public struct ToursView: View {
    @Environment(AppState.self) private var appState
    @State private var savedTours: [Tour] = []
    @State private var showCreateTourSheet = false
    @State private var tourToDelete: Tour?
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""

    private let storage = TourStorage()

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if savedTours.isEmpty {
                    emptyState
                } else if filteredTours.isEmpty {
                    searchEmptyState
                } else {
                    toursList
                }
            }
            .navigationTitle("Tours")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTourSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(appState.selectedPOIs.isEmpty)
                }
            }
            .sheet(isPresented: $showCreateTourSheet) {
                CreateTourSheet(
                    selectedPOIs: Array(appState.selectedPOIs),
                    user: appState.currentUser,
                    vehicle: appState.currentVehicle,
                    onSave: { tour in
                        storage.addTour(tour)
                        savedTours = storage.loadTours()
                        showCreateTourSheet = false
                    }
                )
            }
            .confirmationDialog(
                "Delete Tour?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible,
                presenting: tourToDelete
            ) { tour in
                Button("Delete", role: .destructive) {
                    storage.deleteTour(tour)
                    savedTours = storage.loadTours()
                }
                Button("Cancel", role: .cancel) {}
            } message: { tour in
                Text("Are you sure you want to delete '\(tour.name)'? This cannot be undone.")
            }
            .onAppear {
                savedTours = storage.loadTours()
            }
            .searchable(
                text: $searchText,
                prompt: "Search tours..."
            )
        }
    }

    private var filteredTours: [Tour] {
        if searchText.isEmpty {
            return savedTours
        } else {
            return savedTours.filter { tour in
                tour.name.localizedCaseInsensitiveContains(searchText) ||
                (tour.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("No Saved Tours")
                .font(.title)
                .bold()

            Text("Select POIs from the Discover tab, then tap + to create your first tour")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    private var toursList: some View {
        List {
            ForEach(filteredTours) { tour in
                TourRow(tour: tour)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            tourToDelete = tour
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        startTour(tour)
                    }
            }
        }
    }

    private var searchEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("No Results")
                .font(.title)
                .bold()

            Text("No tours match '\(searchText)'")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    private func startTour(_ tour: Tour) {
        // Extract POIs from waypoints
        let pois = tour.orderedWaypoints.compactMap { waypoint in
            // Create POI from waypoint (simplified - real implementation would store POI reference)
            POI(
                id: waypoint.poiId ?? UUID(),
                name: waypoint.name,
                description: "",
                category: .attraction,
                location: waypoint.location,
                tags: []
            )
        }

        // Load POIs into selected POIs
        appState.selectedPOIs = Set(pois)

        // Navigate to Audio Tour tab
        // Note: Actual navigation would require tab selection state management
    }
}

struct TourRow: View {
    let tour: Tour

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tour.name)
                    .font(.headline)

                Spacer()

                StatusBadge(status: tour.status)
            }

            if let description = tour.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                Label("\(tour.poiStops.count) stops", systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(formatDistance(tour.totalDistanceMiles), systemImage: "road.lanes")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(formatDuration(tour.estimatedDurationMinutes), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Created \(tour.createdAt, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func formatDistance(_ miles: Double) -> String {
        String(format: "%.1f mi", miles)
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

struct StatusBadge: View {
    let status: TourStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(status.rawValue)
        }
        .font(.caption)
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private var icon: String {
        switch status {
        case .draft: return "pencil"
        case .planned: return "checkmark.circle"
        case .active: return "waveform.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    private var color: Color {
        switch status {
        case .draft: return .orange
        case .planned: return .blue
        case .active: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

struct CreateTourSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService()

    let selectedPOIs: [POI]
    let user: User?
    let vehicle: EVProfile?
    let onSave: (Tour) -> Void

    @State private var tourName = ""
    @State private var tourDescription = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tour Details") {
                    TextField("Tour Name", text: $tourName)
                    TextField("Description (optional)", text: $tourDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Route") {
                    Text("\(selectedPOIs.count) POIs selected")
                        .foregroundStyle(.secondary)

                    ForEach(selectedPOIs) { poi in
                        HStack {
                            Text(poi.name)
                            Spacer()
                            Text(poi.category.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let location = locationService.currentLocation {
                    Section("Estimates") {
                        LabeledContent("Distance", value: String(format: "%.1f miles", calculateDistance(from: location)))
                        LabeledContent("Duration", value: formatDuration(calculateDuration(from: location)))
                    }
                }
            }
            .navigationTitle("Create Tour")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveTour()
                    }
                    .disabled(tourName.isEmpty)
                }
            }
            .onAppear {
                locationService.requestLocationPermission()
            }
        }
    }

    private func saveTour() {
        guard let location = locationService.currentLocation,
              let userId = user?.id,
              let vehicleId = vehicle?.id else { return }

        // Calculate route estimates
        let totalDistance = calculateDistance(from: location)
        let duration = calculateDuration(from: location)

        // Create waypoints from POIs
        let waypoints = selectedPOIs.enumerated().map { (index, poi) in
            Waypoint(
                id: UUID(),
                poiId: poi.id,
                location: poi.location,
                name: poi.name,
                notes: poi.description,
                durationMinutes: 15,
                sequenceNumber: index,
                isChargingStop: false
            )
        }

        let tour = Tour(
            name: tourName,
            description: tourDescription.isEmpty ? nil : tourDescription,
            waypoints: waypoints,
            creatorId: userId,
            vehicleId: vehicleId,
            status: .draft,
            totalDistanceMiles: totalDistance,
            estimatedDurationMinutes: duration
        )

        onSave(tour)
    }

    private func calculateDistance(from startLocation: GeoLocation) -> Double {
        var totalDistance = 0.0
        var previousLocation = startLocation

        for poi in selectedPOIs {
            totalDistance += previousLocation.distance(to: poi.location)
            previousLocation = poi.location
        }

        return totalDistance
    }

    private func calculateDuration(from startLocation: GeoLocation) -> Int {
        let distance = calculateDistance(from: startLocation)
        let drivingTimeMinutes = Int((distance / 45.0) * 60.0) // 45 mph average
        let stopTimeMinutes = selectedPOIs.count * 15 // 15 min per stop
        return drivingTimeMinutes + stopTimeMinutes
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours) hours \(mins) minutes"
        } else {
            return "\(mins) minutes"
        }
    }
}

#Preview {
    ToursView()
        .environment(AppState())
}
