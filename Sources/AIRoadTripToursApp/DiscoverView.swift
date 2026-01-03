import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

#if canImport(UIKit)
import UIKit
#endif

public struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var locationService = LocationService()
    @State private var searchLocation = ""
    @State private var pois: [POI] = []
    @State private var isSearching = false
    @State private var showLocationPermissionAlert = false
    @State private var selectedCategories: Set<POICategory> = []
    @State private var showCategoryFilter = false
    @State private var poiSearchText = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Location status
                if locationService.currentLocation != nil {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.green)
                        Text("Using your current location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                } else if locationService.authorizationStatus == .denied {
                    HStack {
                        Image(systemName: "location.slash")
                            .foregroundStyle(.red)
                        Text("Location access denied")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        #if canImport(UIKit)
                        Button("Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                        #endif
                    }
                    .padding(.horizontal)
                }

                // Category Filter
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Filter by Category", systemImage: "line.3.horizontal.decrease.circle")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if !selectedCategories.isEmpty {
                            Button("Clear") {
                                selectedCategories.removeAll()
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(POICategory.allCases, id: \.self) { category in
                                CategoryFilterChip(
                                    category: category,
                                    isSelected: selectedCategories.contains(category),
                                    onTap: {
                                        if selectedCategories.contains(category) {
                                            selectedCategories.remove(category)
                                        } else {
                                            selectedCategories.insert(category)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Search controls
                VStack(spacing: 12) {
                    TextField("Or enter a location...", text: $searchLocation)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    Button {
                        Task { await searchNearby() }
                    } label: {
                        Label(locationService.currentLocation != nil ? "Search Nearby POIs" : "Use Current Location", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(isSearching)
                }
                .padding(.top)

                if isSearching {
                    ProgressView("Searching...")
                        .padding()
                } else if pois.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)

                        Text(locationService.currentLocation != nil ? "Tap to search for nearby points of interest" : "Allow location access to discover nearby places")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                } else if filteredPOIs.isEmpty {
                    // Show empty search results
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)

                        Text("No Results")
                            .font(.headline)
                            .bold()

                        Text("No POIs match '\(poiSearchText)'")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(filteredPOIs) { poi in
                        NavigationLink(destination: POIDetailView(poi: poi)) {
                            HStack {
                                POIRow(poi: poi)
                                Spacer()
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                toggleSelection(poi)
                            } label: {
                                if appState.selectedPOIs.contains(poi) {
                                    Label("Remove", systemImage: "checkmark.circle.fill")
                                } else {
                                    Label("Add", systemImage: "plus.circle")
                                }
                            }
                            .tint(appState.selectedPOIs.contains(poi) ? .red : .green)
                        }
                    }

                    // Selection summary and navigation
                    if !appState.selectedPOIs.isEmpty {
                        VStack(spacing: 12) {
                            Text("\(appState.selectedPOIs.count) POIs selected")
                                .font(.headline)

                            HStack(spacing: 12) {
                                Button {
                                    appState.selectedPOIs.removeAll()
                                } label: {
                                    Label("Clear", systemImage: "xmark.circle")
                                        .padding()
                                        .background(.red.opacity(0.1))
                                        .foregroundStyle(.red)
                                        .cornerRadius(8)
                                }

                                NavigationLink(destination: AudioTourView()) {
                                    Label("Start Tour", systemImage: "play.circle.fill")
                                        .padding()
                                        .background(.green)
                                        .foregroundStyle(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                    }
                }
            }
            .navigationTitle("Discover")
            .task {
                locationService.requestLocationPermission()
            }
            .alert("Location Permission Required", isPresented: $showLocationPermissionAlert) {
                #if canImport(UIKit)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                #endif
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable location access in Settings to discover nearby places.")
            }
            .searchable(
                text: $poiSearchText,
                prompt: "Search POIs by name or description..."
            )
        }
    }

    private var filteredPOIs: [POI] {
        if poiSearchText.isEmpty {
            return pois
        } else {
            return pois.filter { poi in
                poi.name.localizedCaseInsensitiveContains(poiSearchText) ||
                (poi.description?.localizedCaseInsensitiveContains(poiSearchText) ?? false) ||
                poi.tags.contains(where: { $0.localizedCaseInsensitiveContains(poiSearchText) })
            }
        }
    }

    private func searchNearby() async {
        isSearching = true
        defer { isSearching = false }

        do {
            // Use actual user location if available, otherwise fallback
            let searchLocation: GeoLocation
            if let userLocation = locationService.currentLocation {
                searchLocation = userLocation
            } else if !self.searchLocation.isEmpty {
                // TODO: Geocode the search location text
                // For now, fallback to Portland
                searchLocation = GeoLocation(latitude: 45.5152, longitude: -122.6784)
            } else {
                // No location available
                showLocationPermissionAlert = true
                return
            }

            pois = try await appState.poiRepository.findNearby(
                location: searchLocation,
                radiusMiles: 25.0,
                categories: selectedCategories.isEmpty ? nil : selectedCategories
            )
        } catch {
            print("Error searching POIs: \(error)")
        }
    }

    private func toggleSelection(_ poi: POI) {
        if appState.selectedPOIs.contains(poi) {
            appState.selectedPOIs.remove(poi)
        } else {
            appState.selectedPOIs.insert(poi)
        }
    }
}

struct POIRow: View {
    let poi: POI
    @State private var thumbnailImage: POIImage?
    @State private var isLoadingImage = false

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail image
            Group {
                if let image = thumbnailImage {
                    AsyncImage(url: URL(string: image.thumbnailURL ?? image.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            Image(systemName: "photo")
                                .foregroundStyle(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else if isLoadingImage {
                    ProgressView()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: 60, height: 60)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .clipped()

            // POI info
            VStack(alignment: .leading, spacing: 8) {
                Text(poi.name)
                    .font(.headline)

                HStack {
                    Label(poi.category.rawValue, systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let rating = poi.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating.averageRating))
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        isLoadingImage = true
        defer { isLoadingImage = false }

        do {
            let imageService = POIImageService()
            let images = try await imageService.fetchImages(for: poi, limit: 1)
            thumbnailImage = images.first
        } catch {
            // Silently fail - will show placeholder
        }
    }
}

// MARK: - Category Filter Chip

struct CategoryFilterChip: View {
    let category: POICategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: categoryIcon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? categoryColor : Color.gray.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    private var categoryIcon: String {
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

    private var categoryColor: Color {
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

#Preview {
    DiscoverView()
        .environment(AppState())
}
