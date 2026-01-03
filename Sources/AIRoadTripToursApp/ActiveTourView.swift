import SwiftUI
import AVFoundation
import AIRoadTripToursCore
import AIRoadTripToursServices

/// Active tour view showing current POI narration with images and proximity info.
@available(iOS 17.0, *)
struct ActiveTourView: View {

    let narration: Narration
    let images: [POIImage]

    var body: some View {
        ZStack {
            // Background slideshow
            ImageSlideshowView(images: images)
                .ignoresSafeArea()

            // Overlay content
            VStack {
                Spacer()

                // POI info card
                poiInfoCard
            }
            .padding()
        }
    }

    // MARK: - Components

    private var poiInfoCard: some View {
        VStack(spacing: 12) {
            // POI name
            Text(narration.poiName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            // Narration title
            Text(narration.title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    ActiveTourView(
        narration: Narration(
            id: UUID(),
            poiId: UUID(),
            poiName: "Multnomah Falls",
            title: "Discovering Multnomah Falls",
            content: "Oregon's tallest waterfall...",
            durationSeconds: 60.0,
            source: "Wikipedia + AI"
        ),
        images: [
            POIImage(
                url: "https://picsum.photos/800/600",
                caption: "Multnomah Falls, Oregon",
                attribution: "John Smith (CC-BY)",
                source: "wikipedia"
            )
        ]
    )
}
