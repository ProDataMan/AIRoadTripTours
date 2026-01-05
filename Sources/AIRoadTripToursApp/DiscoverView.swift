import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices
import CoreLocation

#if canImport(UIKit)
import UIKit
#endif

public struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.selectedTab) private var selectedTab
    @StateObject private var locationService = LocationService()
    @State private var searchLocation = ""
    @State private var pois: [POI] = []
    @State private var isSearching = false
    @State private var showLocationPermissionAlert = false
    @State private var selectedCategories: Set<POICategory> = []
    @State private var showCategoryFilter = false
    @State private var poiSearchText = ""
    @State private var referenceLocation: GeoLocation?
    @State private var searchedLocationName: String?
    @State private var sortOrder: POISortOrder = .distance

    public init() {}

    enum POISortOrder: String, CaseIterable {
        case distance = "Distance"
        case category = "Category"
        case name = "Name"
        case rating = "Rating"
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Location status
                if let searchedLocation = searchedLocationName {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Searching near \(searchedLocation)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                } else if locationService.currentLocation != nil {
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

                // Sort order picker
                if !pois.isEmpty {
                    HStack {
                        Label("Sort by", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Sort by", selection: $sortOrder) {
                            ForEach(POISortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                }

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
                    List(sortedAndFilteredPOIs) { poi in
                        NavigationLink(destination: POIDetailView(poi: poi)) {
                            HStack {
                                POIRow(poi: poi, referenceLocation: referenceLocation)

                                // Quick add/remove button
                                Button {
                                    toggleSelection(poi)
                                } label: {
                                    Image(systemName: appState.selectedPOIs.contains(poi) ? "checkmark.circle.fill" : "plus.circle")
                                        .font(.title2)
                                        .foregroundStyle(appState.selectedPOIs.contains(poi) ? .green : .blue)
                                }
                                .buttonStyle(.plain)
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

                                Button {
                                    selectedTab.wrappedValue = 2 // Switch to Audio Tour tab
                                } label: {
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

    private var sortedAndFilteredPOIs: [POI] {
        let filtered = filteredPOIs

        switch sortOrder {
        case .distance:
            guard let refLocation = referenceLocation else { return filtered }
            return filtered.sorted(by: { poi1, poi2 in
                let dist1 = poi1.location.distance(to: refLocation)
                let dist2 = poi2.location.distance(to: refLocation)
                return dist1 < dist2
            })
        case .category:
            return filtered.sorted(by: { $0.category.rawValue < $1.category.rawValue })
        case .name:
            return filtered.sorted(by: { $0.name < $1.name })
        case .rating:
            return filtered.sorted(by: { poi1, poi2 in
                let rating1 = poi1.rating?.averageRating ?? 0
                let rating2 = poi2.rating?.averageRating ?? 0
                return rating1 > rating2 // Higher ratings first
            })
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
            // Use actual user location if available, otherwise geocode search text
            let searchLocation: GeoLocation
            if !self.searchLocation.isEmpty {
                // Geocode the search location text
                let geocodedLocation = await geocodeLocation(self.searchLocation)
                if let location = geocodedLocation {
                    searchLocation = location
                    searchedLocationName = self.searchLocation.capitalized
                    referenceLocation = location
                } else {
                    // Geocoding failed
                    print("Failed to geocode location: \(self.searchLocation)")
                    return
                }
            } else if let userLocation = locationService.currentLocation {
                searchLocation = userLocation
                searchedLocationName = nil
                referenceLocation = userLocation
            } else {
                // No location available
                showLocationPermissionAlert = true
                return
            }

            let foundPOIs = try await appState.poiRepository.findNearby(
                location: searchLocation,
                radiusMiles: 25.0,
                categories: selectedCategories.isEmpty ? nil : selectedCategories
            )

            // Enrich POIs with Google Places descriptions
            print("📝 Enriching \(foundPOIs.count) POIs with Google Places data...")
            if #available(iOS 17.0, macOS 14.0, *) {
                let enrichmentService = POIEnrichmentService()
                pois = await enrichmentService.enrichBatch(foundPOIs)
                let enrichedCount = pois.filter { $0.description != nil && !$0.description!.isEmpty }.count
                print("✅ Enriched \(enrichedCount) of \(pois.count) POIs with descriptions")
            } else {
                pois = foundPOIs
            }
        } catch {
            print("Error searching POIs: \(error)")
        }
    }

    private func geocodeLocation(_ locationName: String) async -> GeoLocation? {
        #if canImport(CoreLocation)
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(locationName)
            if let location = placemarks.first?.location {
                return GeoLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
        } catch {
            print("Geocoding error: \(error)")
        }
        #endif
        return nil
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
    @Environment(AppState.self) private var appState
    let poi: POI
    let referenceLocation: GeoLocation?
    @State private var thumbnailImage: POIImage?
    @State private var isLoadingImage = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail image with checkmark overlay
            ZStack(alignment: .topLeading) {
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
                .frame(width: 80, height: 80)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .clipped()

                // Green checkmark indicator if POI is added to tour
                if appState.selectedPOIs.contains(poi) {
                    ZStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: 4)
                    .shadow(radius: 2)
                }
            }
            .frame(width: 80, height: 80)

            // POI info
            VStack(alignment: .leading, spacing: 6) {
                // Name with open status indicator
                HStack(spacing: 6) {
                    Text(poi.name)
                        .font(.headline)
                        .lineLimit(2)

                    if let hours = poi.hours, let isOpen = hours.isOpenNow {
                        Circle()
                            .fill(isOpen ? .green : .red)
                            .frame(width: 6, height: 6)
                        Text(isOpen ? "Open" : "Closed")
                            .font(.caption2)
                            .foregroundStyle(isOpen ? .green : .red)
                    }
                }

                // Category, distance, rating row
                HStack {
                    Label(poi.category.rawValue, systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let refLocation = referenceLocation {
                        let distance = poi.location.distance(to: refLocation)
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Label(String(format: "%.1f mi", distance), systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let rating = poi.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating.averageRating))
                                .font(.caption)
                            Text("(\(rating.totalRatings))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Price level indicator
                if let rating = poi.rating, let priceLevel = rating.priceLevel {
                    Text(String(repeating: "$", count: priceLevel))
                        .font(.caption)
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                }

                // Brief description
                if let description = poi.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Contact info row
                HStack(spacing: 10) {
                    if let phone = poi.contact?.phone {
                        HStack(spacing: 2) {
                            Image(systemName: "phone.fill")
                                .font(.caption2)
                            Text(formatPhone(phone))
                                .font(.caption2)
                        }
                        .foregroundStyle(.blue)
                    }

                    if poi.contact?.website != nil {
                        HStack(spacing: 2) {
                            Image(systemName: "globe")
                                .font(.caption2)
                            Text("Website")
                                .font(.caption2)
                        }
                        .foregroundStyle(.blue)
                    }
                }

                // Hours summary
                if let hours = poi.hours {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(formatHoursSummary(hours.description))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 6)
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

    private func formatPhone(_ phone: String) -> String {
        // Extract just the digits for a cleaner display
        let digits = phone.filter { $0.isNumber }
        if digits.count == 10 {
            let area = digits.prefix(3)
            let prefix = digits.dropFirst(3).prefix(3)
            let line = digits.suffix(4)
            return "(\(area)) \(prefix)-\(line)"
        }
        return phone
    }

    private func formatHoursSummary(_ hours: String) -> String {
        // Get first part before comma for brevity
        if let firstPart = hours.components(separatedBy: ",").first {
            return firstPart
        }
        return hours
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
