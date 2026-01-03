import SwiftUI
import AIRoadTripToursCore

/// A slideshow view that displays POI images with captions and attribution.
@available(iOS 17.0, *)
struct ImageSlideshowView: View {

    let images: [POIImage]
    let interval: TimeInterval

    @State private var currentIndex: Int = 0
    @State private var timer: Timer?

    init(images: [POIImage], interval: TimeInterval = 12.0) {
        self.images = images
        self.interval = interval
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !images.isEmpty {
                    // Background image
                    AsyncImage(url: URL(string: images[currentIndex].url)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .id(currentIndex) // Force view recreation for transition

                    // Gradient overlay for readability
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    // Caption and attribution
                    VStack {
                        Spacer()

                        VStack(alignment: .leading, spacing: 8) {
                            if let caption = images[currentIndex].caption, !caption.isEmpty {
                                Text(caption)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                            }

                            if let attribution = images[currentIndex].attribution, !attribution.isEmpty {
                                Text("Photo: \(attribution)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                            }

                            // Page indicator
                            HStack(spacing: 6) {
                                ForEach(0..<images.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                } else {
                    // Placeholder when no images available
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                        Text("No images available")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            startSlideshow()
        }
        .onDisappear {
            stopSlideshow()
        }
    }

    // MARK: - Private

    private func startSlideshow() {
        guard images.count > 1 else { return }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                withAnimation {
                    currentIndex = (currentIndex + 1) % images.count
                }
            }
        }
    }

    private func stopSlideshow() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview("Single Image") {
    ImageSlideshowView(
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

#Preview("Multiple Images") {
    ImageSlideshowView(
        images: [
            POIImage(
                url: "https://picsum.photos/800/600?random=1",
                caption: "Multnomah Falls from below",
                attribution: "Jane Doe (CC-BY)",
                source: "wikipedia"
            ),
            POIImage(
                url: "https://picsum.photos/800/600?random=2",
                caption: "Benson Bridge spanning the falls",
                attribution: "Bob Johnson (CC-BY)",
                source: "wikipedia"
            ),
            POIImage(
                url: "https://picsum.photos/800/600?random=3",
                caption: "View from the top of the falls",
                attribution: "Alice Williams (CC-BY)",
                source: "wikipedia"
            )
        ],
        interval: 5.0 // Faster for preview
    )
}
