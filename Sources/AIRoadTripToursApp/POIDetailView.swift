import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices
#if canImport(MapKit)
import MapKit
#endif

/// Detailed view for a single POI with images, description, and actions.
public struct POIDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var imageLoader = POIImageLoader()
    @StateObject private var locationService = LocationService()
    @State private var showRoutePreview = false
    @State private var routeInfo: RouteInfo?
    @State private var isLoadingRoute = false

    private let navigationService = NavigationService()

    let poi: POI

    public init(poi: POI) {
        self.poi = poi
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Image gallery
                if !imageLoader.images.isEmpty {
                    TabView {
                        ForEach(imageLoader.images) { image in
                            AsyncImage(url: URL(string: image.url)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(height: 300)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 300)
                                        .clipped()
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.gray)
                                        .frame(height: 300)
                                @unknown default:
                                    EmptyView()
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                if let caption = image.caption, !caption.isEmpty {
                                    Text(caption)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let attribution = image.attribution, !attribution.isEmpty {
                                    Text(attribution)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    #if os(iOS)
                    .tabViewStyle(.page)
                    #endif
                    .frame(height: 360)
                } else if imageLoader.isLoading {
                    ProgressView("Loading images...")
                        .frame(height: 300)
                } else {
                    // Placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.gray.opacity(0.2))

                        VStack(spacing: 8) {
                            Image(systemName: categoryIcon(poi.category))
                                .font(.system(size: 60))
                                .foregroundStyle(.gray)
                            Text("No images available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 300)
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(poi.name)
                                .font(.title)
                                .fontWeight(.bold)

                            HStack {
                                CategoryBadge(category: poi.category)

                                if let description = poi.description, !description.isEmpty {
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }

                        Spacer()

                        Button {
                            toggleFavorite()
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(isFavorite ? .yellow : .gray)
                        }
                    }

                    // Tags
                    if !poi.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(poi.tags).sorted(), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }

                    Divider()

                    // Actions
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await loadRoutePreview()
                            }
                        } label: {
                            HStack {
                                if isLoadingRoute {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoadingRoute)

                        Button {
                            toggleSelection()
                        } label: {
                            Label(
                                isSelected ? "Remove" : "Add to Tour",
                                systemImage: isSelected ? "checkmark.circle.fill" : "plus.circle"
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isSelected ? .green.opacity(0.1) : .gray.opacity(0.1))
                            .foregroundStyle(isSelected ? .green : .primary)
                            .cornerRadius(12)
                        }
                    }

                    Divider()

                    // Location info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location")
                            .font(.headline)

                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Coordinates")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.4f, %.4f", poi.location.latitude, poi.location.longitude))
                                    .font(.caption)
                                    .monospaced()
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("POI Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showRoutePreview) {
            if let route = routeInfo {
                RoutePreviewSheet(
                    poi: poi,
                    routeInfo: route,
                    onStartNavigation: {
                        Task {
                            await startNavigation()
                        }
                    }
                )
            }
        }
        .task {
            await imageLoader.loadImages(for: poi)
            locationService.requestLocationPermission()
        }
    }

    private var isSelected: Bool {
        appState.selectedPOIs.contains(poi)
    }

    private var isFavorite: Bool {
        appState.favoritesStorage.isFavorite(poi.id)
    }

    private func toggleFavorite() {
        appState.favoritesStorage.toggleFavorite(poi.id)
    }

    private func toggleSelection() {
        if isSelected {
            appState.selectedPOIs.remove(poi)
        } else {
            appState.selectedPOIs.insert(poi)
            // Dismiss back to Discover page after adding to tour
            dismiss()
        }
    }

    private func loadRoutePreview() async {
        guard let userLocation = locationService.currentLocation else {
            // If no location, open Maps directly
            openInMaps()
            return
        }

        isLoadingRoute = true
        defer { isLoadingRoute = false }

        #if canImport(MapKit)
        do {
            routeInfo = try await navigationService.getRoute(
                from: userLocation,
                to: poi.location
            )
            showRoutePreview = true
        } catch {
            print("Error loading route: \(error)")
            // Fallback to direct Maps launch
            openInMaps()
        }
        #else
        openInMaps()
        #endif
    }

    private func startNavigation() async {
        showRoutePreview = false
        #if canImport(MapKit)
        let success = await navigationService.navigate(to: poi)
        if !success {
            print("Failed to launch navigation")
        }
        #endif
    }

    private func openInMaps() {
        #if canImport(MapKit)
        let coordinate = CLLocationCoordinate2D(
            latitude: poi.location.latitude,
            longitude: poi.location.longitude
        )
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = poi.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
        #endif
    }

    private func categoryIcon(_ category: POICategory) -> String {
        switch category {
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer"
        case .attraction: return "star.fill"
        case .museum: return "building.columns"
        case .park: return "tree"
        case .shopping: return "bag"
        case .scenic: return "eye"
        case .historicSite: return "building"
        case .hiking: return "figure.hiking"
        case .waterfall: return "drop.fill"
        case .beach: return "beach.umbrella"
        case .lake: return "water.waves"
        case .evCharger: return "bolt.car"
        case .hotel: return "bed.double"
        case .entertainment: return "theatermasks"
        }
    }
}

struct CategoryBadge: View {
    let category: POICategory

    var body: some View {
        Text(category.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .cornerRadius(8)
    }

    private var color: Color {
        switch category {
        case .restaurant: return .orange
        case .cafe: return .brown
        case .attraction: return .purple
        case .museum: return .blue
        case .park: return .green
        case .shopping: return .pink
        case .scenic: return .cyan
        case .historicSite: return .brown
        case .hiking: return .green
        case .waterfall: return .teal
        case .beach: return .yellow
        case .lake: return .blue
        case .evCharger: return .indigo
        case .hotel: return .purple
        case .entertainment: return .pink
        }
    }
}

// MARK: - Route Preview Sheet

struct RoutePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let poi: POI
    let routeInfo: RouteInfo
    let onStartNavigation: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Destination header
                VStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)

                    Text(poi.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Route summary
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        Text(String(format: "%.1f mi", routeInfo.distance))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Distance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text(formatDuration(routeInfo.expectedTravelTime))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)

                // Turn-by-turn preview
                if !routeInfo.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Route Preview")
                                .font(.headline)
                            Spacer()
                            Text("\(routeInfo.steps.count) steps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(routeInfo.steps.prefix(5).indices, id: \.self) { index in
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(.blue.opacity(0.1))
                                                .frame(width: 32, height: 32)
                                            Text("\(index + 1)")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.blue)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(routeInfo.steps[index].instructions)
                                                .font(.subheadline)
                                            Text(String(format: "%.2f mi", routeInfo.steps[index].distance))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(8)
                                }

                                if routeInfo.steps.count > 5 {
                                    Text("+ \(routeInfo.steps.count - 5) more steps")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 300)
                    }
                }

                Spacer()

                // Start navigation button
                Button {
                    onStartNavigation()
                    dismiss()
                } label: {
                    Label("Start Navigation", systemImage: "location.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Route to \(poi.name)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
}

// MARK: - Image Loader

@MainActor
class POIImageLoader: ObservableObject {
    @Published var images: [POIImage] = []
    @Published var isLoading = false

    private let imageService = POIImageService()

    func loadImages(for poi: POI) async {
        isLoading = true
        defer { isLoading = false }

        do {
            images = try await imageService.fetchImages(for: poi, limit: 5)
        } catch {
            print("Error loading images: \(error)")
            images = []
        }
    }
}

#Preview {
    NavigationStack {
        POIDetailView(poi: POI(
            name: "Multnomah Falls",
            description: "Oregon's tallest waterfall at 620 feet",
            category: .waterfall,
            location: GeoLocation(latitude: 45.5762, longitude: -122.1158),
            tags: ["nature", "hiking", "scenic", "photography"]
        ))
        .environment(AppState())
    }
}
