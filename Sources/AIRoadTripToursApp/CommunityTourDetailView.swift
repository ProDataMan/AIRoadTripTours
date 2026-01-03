import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices
#if canImport(MapKit)
import MapKit
#endif

/// Detailed view of a community-shared tour.
public struct CommunityTourDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService()

    let tour: SharedTour

    @State private var ratings: [TourRating] = []
    @State private var feedback: [TourFeedback] = []
    @State private var userRating: TourRating?
    @State private var showingRatingSheet = false
    @State private var showingFeedbackSheet = false
    @State private var isSaved = false
    @State private var showingStartTour = false

    public init(tour: SharedTour) {
        self.tour = tour
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header image placeholder
                    tourHeaderView

                    VStack(alignment: .leading, spacing: 16) {
                        // Title and creator
                        VStack(alignment: .leading, spacing: 8) {
                            Text(tour.title)
                                .font(.title)
                                .fontWeight(.bold)

                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("by \(tour.creatorName)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(tour.sharedAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }

                        // Description
                        Text(tour.description)
                            .font(.body)

                        // Stats
                        tourStatsView

                        Divider()

                        // Rating summary
                        ratingSummaryView

                        Divider()

                        // POI list
                        poiListView

                        Divider()

                        // Recent feedback
                        feedbackListView
                    }
                    .padding()
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            toggleSaved()
                        } label: {
                            Label(isSaved ? "Unsave" : "Save Tour",
                                  systemImage: isSaved ? "bookmark.fill" : "bookmark")
                        }

                        Button {
                            Task {
                                await shareTour()
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        if userRating == nil {
                            Button {
                                showingRatingSheet = true
                            } label: {
                                Label("Rate This Tour", systemImage: "star")
                            }
                        }

                        Button {
                            showingFeedbackSheet = true
                        } label: {
                            Label("Leave Feedback", systemImage: "bubble.left")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                await loadTourData()
            }
            .sheet(isPresented: $showingRatingSheet) {
                RatingSheetView(tour: tour) { rating in
                    Task {
                        await submitRating(rating)
                    }
                }
            }
            .sheet(isPresented: $showingFeedbackSheet) {
                FeedbackSheetView(tour: tour) { feedback in
                    Task {
                        await submitFeedback(feedback)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                startTourButton
            }
        }
    }

    private var tourHeaderView: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if tour.isFeatured {
                        Badge(text: "Featured", color: .white)
                    }
                    if tour.isCurated {
                        Badge(text: "Curated", color: .white)
                    }
                    Spacer()
                }

                HStack {
                    ForEach(Array(tour.categories.prefix(3)), id: \.self) { category in
                        Text(category.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.3))
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
    }

    private var tourStatsView: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "map")
                    Text("\(tour.pois.count) POIs")
                }
                .font(.subheadline)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.right")
                    Text(String(format: "%.0f miles", tour.totalDistance))
                }
                .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(formatDuration(tour.estimatedDuration))
                }
                .font(.subheadline)

                DifficultyBadge(difficulty: tour.difficulty)
            }

            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    private var ratingSummaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Community Rating")
                .font(.headline)

            if tour.metrics.ratingCount > 0 {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.title2)
                            Text(String(format: "%.1f", tour.metrics.averageRating))
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        Text("\(tour.metrics.ratingCount) ratings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .frame(height: 40)

                    VStack(alignment: .leading, spacing: 8) {
                        EngagementRow(icon: "eye", label: "Views", count: tour.metrics.viewCount)
                        EngagementRow(icon: "checkmark.circle", label: "Completed",
                                    count: tour.metrics.completionCount)
                        EngagementRow(icon: "bookmark", label: "Saved",
                                    count: tour.metrics.saveCount)
                    }
                    .font(.caption)

                    Spacer()
                }
            } else {
                Text("No ratings yet. Be the first to rate this tour!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            if userRating != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("You rated this tour")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var poiListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Points of Interest (\(tour.pois.count))")
                .font(.headline)

            ForEach(Array(tour.pois.enumerated()), id: \.element.id) { index, poi in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 30, height: 30)
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(poi.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if let description = poi.description {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Text(poi.category.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(6)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var feedbackListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Community Feedback")
                    .font(.headline)

                Spacer()

                if !feedback.isEmpty {
                    Text("\(feedback.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if feedback.isEmpty {
                Text("No feedback yet. Share your experience!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(feedback.prefix(5)) { item in
                    FeedbackItemView(feedback: item)
                }

                if feedback.count > 5 {
                    Button("View All Feedback (\(feedback.count))") {
                        // Show all feedback
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
            }
        }
    }

    private var startTourButton: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                startTour()
            } label: {
                Label("Start This Tour", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    .padding()
            }
            .background(.regularMaterial)
        }
    }

    private func loadTourData() async {
        ratings = await appState.communityTourRepository.getRatings(for: tour.id)
        feedback = await appState.communityTourRepository.getFeedback(for: tour.id)

        if let userId = appState.currentUser?.id.uuidString {
            userRating = await appState.communityTourRepository.getUserRating(
                userId: userId,
                tourId: tour.id
            )
        }
    }

    private func submitRating(_ rating: TourRating) async {
        do {
            _ = try await appState.communityTourRepository.submitRating(
                tourId: tour.id,
                userId: rating.userId,
                rating: rating
            )
            await loadTourData()
        } catch {
            print("Error submitting rating: \(error)")
        }
    }

    private func submitFeedback(_ newFeedback: TourFeedback) async {
        do {
            _ = try await appState.communityTourRepository.submitFeedback(
                tourId: tour.id,
                feedback: newFeedback
            )
            await loadTourData()
        } catch {
            print("Error submitting feedback: \(error)")
        }
    }

    private func toggleSaved() {
        isSaved.toggle()
        Task {
            if isSaved {
                await appState.communityTourRepository.recordSave(tourId: tour.id)
            }
        }
    }

    private func shareTour() async {
        await appState.communityTourRepository.recordShare(tourId: tour.id)
    }

    private func startTour() {
        // Add POIs to selected set
        appState.selectedPOIs = Set(tour.pois)
        dismiss()

        // Record completion intent
        Task {
            await appState.communityTourRepository.recordView(tourId: tour.id)
        }
    }

    private func formatDuration(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

/// Engagement row component.
struct EngagementRow: View {
    let icon: String
    let label: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 16)
            Text(label)
            Spacer()
            Text("\(count)")
                .fontWeight(.semibold)
        }
    }
}

/// Feedback item display.
struct FeedbackItemView: View {
    let feedback: TourFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.secondary)
                Text(feedback.userName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Label(feedback.type.rawValue, systemImage: feedback.type.icon)
                    .font(.caption)
                    .foregroundStyle(colorForType(feedback.type))
            }

            Text(feedback.comment)
                .font(.subheadline)

            if !feedback.aspects.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(feedback.aspects.prefix(3)), id: \.self) { aspect in
                        Text(aspect.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundStyle(.secondary)
                            .cornerRadius(6)
                    }
                }
            }

            HStack {
                Text(feedback.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if feedback.helpfulCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup")
                        Text("\(feedback.helpfulCount)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func colorForType(_ type: FeedbackType) -> Color {
        switch type {
        case .positive: return .green
        case .constructive: return .blue
        case .issue: return .red
        case .suggestion: return .orange
        }
    }
}

/// Sheet for rating a tour.
struct RatingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let tour: SharedTour
    let onSubmit: (TourRating) -> Void

    @State private var overallRating: Int = 5
    @State private var routeQuality: Int = 5
    @State private var poiQuality: Int = 5
    @State private var narrationQuality: Int = 5
    @State private var experienceRating: Int = 5

    var body: some View {
        NavigationStack {
            Form {
                Section("Rate Your Experience") {
                    StarRatingView(rating: $overallRating, label: "Overall")
                    StarRatingView(rating: $routeQuality, label: "Route")
                    StarRatingView(rating: $poiQuality, label: "POIs")
                    StarRatingView(rating: $narrationQuality, label: "Narration")
                    StarRatingView(rating: $experienceRating, label: "Experience")
                }
            }
            .navigationTitle("Rate Tour")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Submit") {
                        submitRating()
                    }
                }
            }
        }
    }

    private func submitRating() {
        guard let userId = appState.currentUser?.id.uuidString else { return }

        let rating = TourRating(
            tourId: tour.id,
            userId: userId,
            overallRating: overallRating,
            routeQuality: routeQuality,
            poiQuality: poiQuality,
            narrationQuality: narrationQuality,
            experienceRating: experienceRating,
            completedTour: true
        )

        onSubmit(rating)
        dismiss()
    }
}

/// Sheet for submitting feedback.
struct FeedbackSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let tour: SharedTour
    let onSubmit: (TourFeedback) -> Void

    @State private var comment: String = ""
    @State private var feedbackType: FeedbackType = .positive
    @State private var selectedAspects: Set<FeedbackAspect> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback Type") {
                    Picker("Type", selection: $feedbackType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Your Feedback") {
                    TextEditor(text: $comment)
                        .frame(minHeight: 100)
                }

                Section("Aspects") {
                    FlowLayout(spacing: 8) {
                        ForEach(FeedbackAspect.allCases, id: \.self) { aspect in
                            AspectToggleButton(
                                aspect: aspect,
                                isSelected: selectedAspects.contains(aspect)
                            ) {
                                if selectedAspects.contains(aspect) {
                                    selectedAspects.remove(aspect)
                                } else {
                                    selectedAspects.insert(aspect)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Share Feedback")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Submit") {
                        submitFeedback()
                    }
                    .disabled(comment.isEmpty)
                }
            }
        }
    }

    private func submitFeedback() {
        guard let userId = appState.currentUser?.id.uuidString,
              let userName = appState.currentUser?.displayName else { return }

        let feedback = TourFeedback(
            tourId: tour.id,
            userId: userId,
            userName: userName,
            comment: comment,
            type: feedbackType,
            aspects: selectedAspects
        )

        onSubmit(feedback)
        dismiss()
    }
}
