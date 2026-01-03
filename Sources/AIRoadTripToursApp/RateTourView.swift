import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

/// View for rating a completed tour.
public struct RateTourView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let tourHistory: TourHistory
    let onComplete: (TourRating) -> Void

    @State private var overallRating: Int = 5
    @State private var routeQuality: Int = 5
    @State private var poiQuality: Int = 5
    @State private var narrationQuality: Int = 5
    @State private var experienceRating: Int = 5
    @State private var feedbackText: String = ""
    @State private var feedbackType: FeedbackType = .positive
    @State private var selectedAspects: Set<FeedbackAspect> = []
    @State private var isSubmitting = false

    public init(tourHistory: TourHistory, onComplete: @escaping (TourRating) -> Void) {
        self.tourHistory = tourHistory
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Overall Experience") {
                    StarRatingView(rating: $overallRating, label: "Overall Rating")
                }

                Section("Rate Specific Aspects") {
                    StarRatingView(rating: $routeQuality, label: "Route Quality")
                    StarRatingView(rating: $poiQuality, label: "POI Selection")
                    StarRatingView(rating: $narrationQuality, label: "Narration Quality")
                    StarRatingView(rating: $experienceRating, label: "Overall Experience")
                }

                Section("Share Your Thoughts (Optional)") {
                    Picker("Feedback Type", selection: $feedbackType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 100)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What aspects are you commenting on?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

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

                Section("Tour Summary") {
                    TourSummaryRow(
                        icon: "map",
                        label: "POIs",
                        value: "\(tourHistory.pois.count)"
                    )
                    TourSummaryRow(
                        icon: "arrow.left.and.right",
                        label: "Distance",
                        value: String(format: "%.1f mi", tourHistory.totalDistance)
                    )
                    TourSummaryRow(
                        icon: "clock",
                        label: "Duration",
                        value: formatDuration(tourHistory.duration)
                    )
                }
            }
            .navigationTitle("Rate Your Tour")
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
                    Button("Submit") {
                        submitRating()
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func submitRating() {
        guard let userId = appState.currentUser?.id.uuidString else { return }

        isSubmitting = true

        let rating = TourRating(
            tourId: UUID(), // This would be the shared tour ID
            userId: userId,
            overallRating: overallRating,
            routeQuality: routeQuality,
            poiQuality: poiQuality,
            narrationQuality: narrationQuality,
            experienceRating: experienceRating,
            completedTour: true,
            tourDate: tourHistory.startTime
        )

        onComplete(rating)
        dismiss()
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

/// Star rating component.
struct StarRatingView: View {
    @Binding var rating: Int
    let label: String
    let maxRating: Int = 5

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 4) {
                ForEach(1...maxRating, id: \.self) { index in
                    Button {
                        rating = index
                    } label: {
                        Image(systemName: index <= rating ? "star.fill" : "star")
                            .foregroundStyle(index <= rating ? .yellow : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Toggle button for feedback aspects.
struct AspectToggleButton: View {
    let aspect: FeedbackAspect
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(aspect.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

/// Flow layout for wrapping aspect tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))

                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

/// Summary row for tour details.
struct TourSummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    let samplePOI = POI(
        name: "Test POI",
        description: "A test location",
        category: .attraction,
        location: GeoLocation(latitude: 45.5, longitude: -122.6),
        tags: ["test"]
    )

    let sampleHistory = TourHistory(
        pois: [samplePOI, samplePOI],
        startLocation: GeoLocation(latitude: 45.5, longitude: -122.6),
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        totalDistance: 25.5,
        stats: TourStatistics(
            totalToursCompleted: 1,
            totalDistanceMiles: 25.5,
            totalPOIsVisited: 2,
            totalTimeMinutes: 60,
            firstTourDate: Date(),
            lastTourDate: Date(),
            favoritePOICategories: ["Attraction"],
            longestTourMiles: 25.5,
            mostPOIsInOneTour: 2
        )
    )

    RateTourView(tourHistory: sampleHistory) { rating in
        print("Rating submitted: \(rating)")
    }
    .environment(AppState())
}
