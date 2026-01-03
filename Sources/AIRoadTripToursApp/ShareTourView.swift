import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

/// View for sharing a completed tour with the community.
public struct ShareTourView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let tourHistory: TourHistory

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var difficulty: TourDifficulty = .moderate
    @State private var bestSeason: Season = .yearRound
    @State private var isSharing = false
    @State private var showingSuccess = false

    public init(tourHistory: TourHistory) {
        self.tourHistory = tourHistory
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Tour Details") {
                    TextField("Title", text: $title)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif

                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Describe what makes this tour special...")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Tour Information") {
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(TourDifficulty.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }

                    Picker("Best Season", selection: $bestSeason) {
                        ForEach(Season.allCases, id: \.self) { season in
                            Text(season.rawValue).tag(season)
                        }
                    }
                }

                Section("Statistics") {
                    StatRow(label: "POIs", value: "\(tourHistory.pois.count)")
                    StatRow(label: "Distance",
                           value: String(format: "%.1f miles", tourHistory.totalDistance))
                    StatRow(label: "Duration", value: formatDuration(tourHistory.duration))
                }

                Section("Tags") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add tags to help others discover your tour")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(suggestedTags, id: \.self) { tag in
                                TagButton(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag)
                                ) {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Preview") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title.isEmpty ? "My Amazing Tour" : title)
                            .font(.headline)

                        Text(description.isEmpty ?
                             "Add a description to help others understand what makes this tour special." :
                             description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Badge(text: difficulty.rawValue, color: difficultyColor)
                            Badge(text: bestSeason.rawValue, color: .blue)
                        }
                    }
                }
            }
            .navigationTitle("Share Tour")
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
                    Button("Share") {
                        Task {
                            await shareTour()
                        }
                    }
                    .disabled(!canShare || isSharing)
                }
            }
            .alert("Tour Shared!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your tour has been shared with the community. Thank you for contributing!")
            }
            .onAppear {
                generateInitialContent()
            }
        }
    }

    private var canShare: Bool {
        !title.isEmpty && !description.isEmpty
    }

    private var suggestedTags: [String] {
        var tags: Set<String> = []

        // Category-based tags
        for poi in tourHistory.pois {
            tags.insert(poi.category.rawValue)
        }

        // Distance-based tags
        if tourHistory.totalDistance < 50 {
            tags.insert("Short Trip")
        } else if tourHistory.totalDistance < 200 {
            tags.insert("Day Trip")
        } else {
            tags.insert("Road Trip")
        }

        // Duration-based tags
        let hours = tourHistory.duration / 3600
        if hours < 2 {
            tags.insert("Quick Tour")
        } else if hours < 6 {
            tags.insert("Half Day")
        } else {
            tags.insert("Full Day")
        }

        // POI count tags
        if tourHistory.pois.count <= 3 {
            tags.insert("Few Stops")
        } else if tourHistory.pois.count <= 6 {
            tags.insert("Several Stops")
        } else {
            tags.insert("Many Stops")
        }

        return Array(tags).sorted()
    }

    private var difficultyColor: Color {
        switch difficulty {
        case .easy: return .green
        case .moderate: return .orange
        case .challenging: return .red
        }
    }

    private func generateInitialContent() {
        // Generate suggested title
        let poiNames = tourHistory.pois.prefix(3).map { $0.name }
        if poiNames.count == 1 {
            title = poiNames[0]
        } else if poiNames.count == 2 {
            title = "\(poiNames[0]) and \(poiNames[1])"
        } else {
            title = "\(poiNames[0]), \(poiNames[1]), and more"
        }

        // Generate suggested description
        let distance = String(format: "%.1f", tourHistory.totalDistance)
        let hours = Int(tourHistory.duration / 3600)
        let minutes = Int((tourHistory.duration.truncatingRemainder(dividingBy: 3600)) / 60)

        description = "A \(distance)-mile journey through \(tourHistory.pois.count) amazing locations. "
        description += "Estimated time: \(hours)h \(minutes)m. "
        description += "Perfect for exploring \(tourHistory.pois.first?.category.rawValue.lowercased() ?? "the area")."

        // Estimate difficulty
        if tourHistory.totalDistance > 300 || tourHistory.pois.count > 10 {
            difficulty = .challenging
        } else if tourHistory.totalDistance > 100 || tourHistory.pois.count > 5 {
            difficulty = .moderate
        } else {
            difficulty = .easy
        }

        // Pre-select some tags
        selectedTags = Set(suggestedTags.prefix(3))
    }

    private func shareTour() async {
        guard let userId = appState.currentUser?.id.uuidString,
              let userName = appState.currentUser?.displayName else {
            return
        }

        isSharing = true
        defer { isSharing = false }

        do {
            _ = try await appState.communityTourRepository.shareTour(
                tourHistory: tourHistory,
                userId: userId,
                userName: userName,
                title: title,
                description: description,
                tags: selectedTags,
                difficulty: difficulty,
                bestSeason: bestSeason == .yearRound ? nil : bestSeason
            )

            showingSuccess = true
        } catch {
            print("Error sharing tour: \(error)")
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Button for selecting tags.
struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

/// Simple stat row.
struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let samplePOI = POI(
        name: "Crater Lake",
        description: "Stunning volcanic lake",
        category: .lake,
        location: GeoLocation(latitude: 42.9, longitude: -122.1),
        tags: ["nature", "scenic"]
    )

    let sampleHistory = TourHistory(
        pois: [samplePOI, samplePOI, samplePOI],
        startLocation: GeoLocation(latitude: 45.5, longitude: -122.6),
        startTime: Date(),
        endTime: Date().addingTimeInterval(7200),
        totalDistance: 125.5,
        stats: TourStatistics(
            totalToursCompleted: 1,
            totalDistanceMiles: 125.5,
            totalPOIsVisited: 3,
            totalTimeMinutes: 120,
            firstTourDate: Date(),
            lastTourDate: Date(),
            favoritePOICategories: ["Lake"],
            longestTourMiles: 125.5,
            mostPOIsInOneTour: 3
        )
    )

    ShareTourView(tourHistory: sampleHistory)
        .environment(AppState())
}
