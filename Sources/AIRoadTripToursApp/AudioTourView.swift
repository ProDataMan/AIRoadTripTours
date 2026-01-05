import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

public struct AudioTourView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var locationService = LocationService()
    @State private var showMap = false
    @State private var currentWeather: WeatherForecast?
    @State private var isLoadingWeather = false
    @State private var isStartingTour = false // Immediate flag to prevent double-tap

    // Explicitly captured tour data for map (not relying on @Bindable observation)
    @State private var mapPOIs: [POI] = []
    @State private var mapSessions: [NarrationSession] = []

    private let weatherService = WeatherService()
    private let navigationService = NavigationService()

    public init() {}

    private var tourManager: AudioTourManager {
        if #available(iOS 17.0, macOS 14.0, *) {
            return appState.audioTourManager
        } else {
            fatalError("iOS 17.0+ required")
        }
    }

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
                }

                // Tour progress
                if tourManager.isPrepared && !tourManager.sessions.isEmpty {
                    TourProgressCard(
                        currentIndex: tourManager.currentSessionIndex,
                        totalPOIs: tourManager.sessions.count,
                        currentSession: tourManager.currentSessionIndex < tourManager.sessions.count
                            ? tourManager.sessions[tourManager.currentSessionIndex]
                            : nil
                    )
                    .padding(.horizontal)
                } else if !appState.selectedPOIs.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                        Text("\(appState.selectedPOIs.count) POIs selected from Discover tab")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Weather conditions
                if let weather = currentWeather {
                    WeatherView(forecast: weather)
                        .padding(.horizontal)
                } else if isLoadingWeather {
                    HStack {
                        ProgressView()
                        Text("Loading weather...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                // Selected POIs list (show if POIs are selected and tour not prepared)
                if !appState.selectedPOIs.isEmpty && !tourManager.isPrepared {
                    VStack(alignment: .leading, spacing: 12) {
                        // Tour Summary Header
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tour Summary")
                                    .font(.headline)
                                HStack(spacing: 12) {
                                    Label("\(appState.selectedPOIs.count) stops", systemImage: "mappin.and.ellipse")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let userLocation = locationService.currentLocation {
                                        let totalDistance = calculateTotalDistance(
                                            from: userLocation,
                                            pois: Array(appState.selectedPOIs)
                                        )
                                        Label(String(format: "~%.0f mi", totalDistance), systemImage: "road.lanes")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        let estimatedDuration = Int(totalDistance / 45.0 * 60.0) // 45 mph avg
                                        Label("~\(estimatedDuration) min", systemImage: "clock")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()
                        }

                        Divider()

                        // POI Cards Scroll View
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(Array(appState.selectedPOIs)) { poi in
                                    AudioTourPOICard(
                                        poi: poi,
                                        referenceLocation: locationService.currentLocation
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                if tourManager.isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Preparing tour...")
                            .font(.headline)

                        Text("Loading POI information and optimizing route")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    playbackControlsView
                }

                // Show active tour view when playing
                if tourManager.playbackState == .playing || tourManager.playbackState == .paused {
                    if let narration = tourManager.currentNarration {
                        let images = tourManager.getImagesForCurrentPOI()
                        let _ = print("🎨 ActiveTourView: narration=\(narration.poiName), images.count=\(images.count)")
                        ActiveTourView(
                            narration: narration,
                            images: images
                        )
                        .frame(height: 300)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }
            }
            .padding()
            .navigationTitle("Audio Tour")
            .toolbar {
                if tourManager.isPrepared && tourManager.currentSessionIndex < tourManager.sessions.count {
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            Task {
                                await navigateToCurrentPOI()
                            }
                        } label: {
                            Label("Navigate", systemImage: "arrow.triangle.turn.up.right.circle")
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showMap.toggle()
                        } label: {
                            Image(systemName: showMap ? "list.bullet" : "map")
                        }
                    }
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showMap) {
                if #available(iOS 17.0, *) {
                    MapSheetView(
                        pois: mapPOIs,
                        sessions: mapSessions,
                        currentLocation: locationService.currentLocation,
                        showMap: $showMap,
                        tourManager: appState.audioTourManager
                    )
                    .environment(appState)
                    .onAppear {
                        print("🗺️ 🚨 FULL SCREEN MAP PRESENTATION - showMap=\(showMap), mapPOIs.count=\(mapPOIs.count)")
                    }
                } else {
                    Text("Map requires iOS 17.0+")
                        .padding()
                }
            }
            #else
            .sheet(isPresented: $showMap) {
                if #available(macOS 14.0, *) {
                    MapSheetView(
                        pois: mapPOIs,
                        sessions: mapSessions,
                        currentLocation: locationService.currentLocation,
                        showMap: $showMap,
                        tourManager: appState.audioTourManager
                    )
                    .environment(appState)
                    .onAppear {
                        print("🗺️ 🚨 SHEET MAP PRESENTATION - showMap=\(showMap), mapPOIs.count=\(mapPOIs.count)")
                    }
                } else {
                    Text("Map requires macOS 14.0+")
                        .padding()
                }
            }
            #endif
            .task {
                locationService.requestLocationPermission()
                await tourManager.startMonitoring()

                // Fetch weather for current location
                if let location = locationService.currentLocation {
                    await fetchWeather(for: location)
                }

                // Start location monitoring if tour is prepared
                if tourManager.isPrepared, let location = locationService.currentLocation {
                    await tourManager.startLocationMonitoring(userLocation: location, speed: nil)
                }
            }
            .onChange(of: locationService.currentLocation) { oldValue, newValue in
                // Update location monitoring when location changes
                if let location = newValue {
                    if tourManager.isPrepared {
                        Task {
                            await tourManager.startLocationMonitoring(userLocation: location, speed: nil)
                        }
                    }

                    // Update weather
                    Task {
                        await fetchWeather(for: location)
                    }
                }
            }
            .onChange(of: showMap) { oldValue, newValue in
                print("🗺️ 🚨 showMap CHANGED: \(oldValue) → \(newValue), mapPOIs.count=\(mapPOIs.count), mapSessions.count=\(mapSessions.count)")
            }
        }
    }

    @ViewBuilder
    private var playbackControlsView: some View {
        // Playback Controls
        VStack(spacing: 16) {
            if let narration = tourManager.currentNarration {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Now Playing")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(narration.poiName)
                        .font(.title2)
                        .bold()

                    Text(narration.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)
            }

            // Tour Status
            if tourManager.isPrepared {
                HStack(spacing: 12) {
                    Image(systemName: statusIcon)
                        .font(.title2)
                        .foregroundStyle(statusColor)

                    Text(statusText)
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(statusColor.opacity(0.1))
                .cornerRadius(8)
            }

            // Playback State
            if tourManager.playbackState != .idle && tourManager.playbackState != .preparing {
                HStack(spacing: 12) {
                    Image(systemName: playbackStateIcon(tourManager.playbackState))
                        .font(.title2)
                        .foregroundStyle(playbackStateColor(tourManager.playbackState))

                    Text(tourManager.playbackState.rawValue)
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(playbackStateColor(tourManager.playbackState).opacity(0.1))
                .cornerRadius(8)
            }

            // Control Buttons (only show when tour is active)
            if tourManager.isPrepared {
                HStack(spacing: 24) {
                    Button {
                        Task { await tourManager.stopTour() }
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .background(.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .cornerRadius(30)
                    }

                    Button {
                        Task { await tourManager.pauseResume() }
                    } label: {
                        Image(systemName: playPauseIcon(tourManager.playbackState))
                            .font(.title)
                            .frame(width: 80, height: 80)
                            .background(.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(40)
                    }
                    .disabled(tourManager.playbackState == .idle)

                    Button {
                        Task { await tourManager.skip() }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .background(.gray.opacity(0.1))
                            .foregroundStyle(.gray)
                            .cornerRadius(30)
                    }
                    .disabled(tourManager.playbackState == .idle || tourManager.playbackState == .completed)
                }
                .padding()
            }
        }

        Spacer()

        // Show different buttons based on tour state
        if !tourManager.isPrepared {
            // Start Tour Button (only show when tour is not prepared)
            Button {
                // Set flag immediately to prevent double-tap
                guard !isStartingTour else { return }
                isStartingTour = true
                Task { await startAudioTour() }
            } label: {
                Label(
                    appState.selectedPOIs.isEmpty ? "Start Audio Tour (All Nearby POIs)" : "Start Tour (\(appState.selectedPOIs.count) Selected)",
                    systemImage: "play.circle.fill"
                )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background((canStartTour && !isStartingTour) ? .green : .gray)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(!canStartTour || tourManager.isGenerating || isStartingTour)

            if locationService.currentLocation == nil {
                Text("Enable location access to start audio tour")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if tourManager.playbackState == .paused || tourManager.playbackState == .idle {
            // Continue Tour and Cancel Tour buttons side by side when paused
            HStack(spacing: 16) {
                // Cancel Tour Button
                Button {
                    Task { await tourManager.stopTour() }
                } label: {
                    Label("Cancel Tour", systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }

                // Continue Tour Button
                Button {
                    Task {
                        await tourManager.pauseResume()
                        showMap = true
                    }
                } label: {
                    Label("Continue Tour", systemImage: "play.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
    }

    private func playbackStateIcon(_ state: NarrationPlaybackState) -> String {
        switch state {
        case .idle: return "speaker.slash.fill"
        case .preparing: return "hourglass"
        case .playing: return "speaker.wave.3.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private func playbackStateColor(_ state: NarrationPlaybackState) -> Color {
        switch state {
        case .idle: return .gray
        case .preparing: return .orange
        case .playing: return .blue
        case .paused: return .yellow
        case .completed: return .green
        case .failed: return .red
        }
    }

    private func playPauseIcon(_ state: NarrationPlaybackState) -> String {
        state == .playing ? "pause.fill" : "play.fill"
    }

    private var canStartTour: Bool {
        locationService.currentLocation != nil && !tourManager.isPrepared
    }

    private var statusIcon: String {
        if tourManager.isMonitoring {
            return "location.fill.viewfinder"
        } else {
            return "hourglass"
        }
    }

    private var statusText: String {
        if tourManager.isMonitoring {
            if tourManager.currentSessionIndex < tourManager.sessions.count {
                let session = tourManager.sessions[tourManager.currentSessionIndex]
                let distance = String(format: "%.1f", session.distanceToPOI)
                let eta = Int(session.estimatedTimeToArrival / 60)
                return "Approaching \(session.poi.name) - \(distance) mi / \(eta) min"
            }
            return "Monitoring location..."
        } else {
            return "Tour prepared - waiting for proximity"
        }
    }

    private var statusColor: Color {
        tourManager.isMonitoring ? .blue : .orange
    }

    private func startAudioTour() async {
        print("🎯 Start Audio Tour button pressed")

        // Reset flag when function exits (success or error)
        defer {
            isStartingTour = false
        }

        guard let userLocation = locationService.currentLocation else {
            print("❌ No location available")
            return
        }

        print("✅ Location available: \(userLocation.latitude), \(userLocation.longitude)")

        // Start generating immediately with loading state
        tourManager.isGenerating = true

        do {
            print("🔍 Getting POIs...")
            // Use selected POIs if any, otherwise find nearby POIs
            let pois: [POI]
            if !appState.selectedPOIs.isEmpty {
                print("📍 Using \(appState.selectedPOIs.count) selected POIs")
                // Use selected POIs and optimize route
                let optimizer = RouteOptimizer()
                pois = await optimizer.optimizeRoute(
                    startingFrom: userLocation,
                    visiting: Array(appState.selectedPOIs)
                )
            } else {
                print("🔎 Finding nearby POIs...")
                // Find all nearby POIs and optimize route
                let nearbyPOIs = try await appState.poiRepository.findNearby(
                    location: userLocation,
                    radiusMiles: 25.0,
                    categories: nil
                )
                print("📍 Found \(nearbyPOIs.count) nearby POIs")

                let optimizer = RouteOptimizer()
                pois = await optimizer.optimizeRoute(
                    startingFrom: userLocation,
                    visiting: Array(nearbyPOIs.prefix(5))
                )
            }

            print("🚀 Preparing tour with \(pois.count) POIs...")

            // Prepare tour and get data directly
            let (preparedPOIs, preparedSessions) = await tourManager.prepareTour(
                pois: pois,
                userInterests: appState.currentUser?.interests ?? []
            )

            // Use the returned data (doesn't rely on property reads)
            mapPOIs = preparedPOIs
            mapSessions = preparedSessions
            print("🗺️ 📸 Snapshot captured: mapPOIs.count=\(mapPOIs.count), mapSessions.count=\(mapSessions.count)")

            // Open map if we have POIs
            if !mapPOIs.isEmpty {
                print("🗺️ 🚨 Opening map with \(mapPOIs.count) POIs")
                showMap = true
            }

            print("✅ Tour prepared successfully")

            // Play welcome introduction in background (map is already visible)
            print("🔊 Starting welcome introduction (background)")
            Task {
                await tourManager.playWelcomeIntroduction(
                    poiCount: preparedPOIs.count,
                    sessionsToIntroduce: preparedSessions
                )
                print("🔊 Welcome introduction completed")
            }

        } catch {
            print("❌ Error starting audio tour: \(error)")
            tourManager.isGenerating = false
            showMap = false // Close map if error
        }
    }

    private func navigateToCurrentPOI() async {
        guard tourManager.currentSessionIndex < tourManager.sessions.count else {
            return
        }

        let currentPOI = tourManager.sessions[tourManager.currentSessionIndex].poi

        #if canImport(MapKit)
        let success = await navigationService.navigate(to: currentPOI)
        if !success {
            print("Failed to launch navigation to \(currentPOI.name)")
        }
        #endif
    }

    private func fetchWeather(for location: GeoLocation) async {
        isLoadingWeather = true
        defer { isLoadingWeather = false }

        do {
            currentWeather = try await weatherService.fetchWeather(for: location)
        } catch {
            print("Error fetching weather: \(error)")
            currentWeather = nil
        }
    }

    private func calculateTotalDistance(from start: GeoLocation, pois: [POI]) -> Double {
        guard !pois.isEmpty else { return 0 }

        var total = 0.0
        var current = start

        for poi in pois {
            total += current.distance(to: poi.location)
            current = poi.location
        }

        return total
    }
}

// MARK: - Tour Progress Card

struct TourProgressCard: View {
    let currentIndex: Int
    let totalPOIs: Int
    let currentSession: NarrationSession?

    var body: some View {
        VStack(spacing: 12) {
            // Progress indicator
            HStack {
                Text("Tour Progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("POI \(currentIndex + 1) of \(totalPOIs)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }

            // Progress bar
            ProgressView(value: Double(currentIndex), total: Double(totalPOIs))
                .tint(.blue)

            if let session = currentSession {
                Divider()

                // Current POI info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.blue)
                        Text(session.poi.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        PhaseBadge(phase: session.currentPhase)
                    }

                    // Distance and ETA
                    HStack(spacing: 20) {
                        Label(formatDistance(session.distanceToPOI), systemImage: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label(formatETA(session.estimatedTimeToArrival), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Remaining POIs
            if currentIndex < totalPOIs - 1 {
                Divider()

                HStack {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text("\(totalPOIs - currentIndex - 1) stops remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
    }

    private func formatDistance(_ miles: Double) -> String {
        if miles < 0.1 {
            return "< 0.1 mi"
        } else {
            return String(format: "%.1f mi", miles)
        }
    }

    private func formatETA(_ seconds: TimeInterval) -> String {
        if seconds.isInfinite || seconds <= 0 {
            return "--"
        }

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

struct PhaseBadge: View {
    let phase: NarrationPhase

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption2)
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }

    private var icon: String {
        switch phase {
        case .pending: return "clock"
        case .approaching: return "arrow.right.circle"
        case .detailed: return "info.circle"
        case .arrival: return "location.circle"
        case .guidedTour: return "signpost.right"
        case .passed: return "checkmark.circle"
        }
    }

    private var label: String {
        switch phase {
        case .pending: return "Waiting"
        case .approaching: return "Approaching"
        case .detailed: return "Learning"
        case .arrival: return "Arriving"
        case .guidedTour: return "Tour"
        case .passed: return "Passed"
        }
    }

    private var color: Color {
        switch phase {
        case .pending: return .gray
        case .approaching: return .orange
        case .detailed: return .blue
        case .arrival: return .green
        case .guidedTour: return .purple
        case .passed: return .secondary
        }
    }
}

// MARK: - Audio Tour POI Card

struct AudioTourPOICard: View {
    let poi: POI
    let referenceLocation: GeoLocation?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // POI Icon
            Image(systemName: categoryIcon(for: poi.category))
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 50, height: 50)
                .background(.blue.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 6) {
                // Name with open status
                HStack(spacing: 4) {
                    Text(poi.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    if let hours = poi.hours, let isOpen = hours.isOpenNow {
                        Circle()
                            .fill(isOpen ? .green : .red)
                            .frame(width: 5, height: 5)
                    }
                }

                HStack(spacing: 8) {
                    Label(poi.category.rawValue, systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let location = referenceLocation {
                        let distance = location.distance(to: poi.location)
                        Label(formatDistance(distance), systemImage: "location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let rating = poi.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                            Text(String(format: "%.1f", rating.averageRating))
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                    }
                }

                // Price level
                if let rating = poi.rating, let priceLevel = rating.priceLevel {
                    Text(String(repeating: "$", count: priceLevel))
                        .font(.caption)
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                }

                if let description = poi.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Contact info
                HStack(spacing: 8) {
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
                        Image(systemName: "globe")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(.background)
        .cornerRadius(8)
    }

    private func categoryIcon(for category: POICategory) -> String {
        switch category {
        case .museum: return "building.columns"
        case .park: return "tree"
        case .historicSite: return "map"
        case .waterfall: return "water.waves"
        case .beach: return "beach.umbrella"
        case .lake: return "water.waves"
        case .hiking: return "figure.hiking"
        case .scenic: return "eye"
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer"
        case .hotel: return "bed.double"
        case .evCharger: return "bolt.car"
        case .attraction: return "star"
        case .shopping: return "cart"
        case .entertainment: return "popcorn"
        }
    }

    private func formatDistance(_ miles: Double) -> String {
        if miles < 0.1 {
            return "< 0.1 mi"
        } else if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }

    private func formatPhone(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        if digits.count == 10 {
            let area = digits.prefix(3)
            let prefix = digits.dropFirst(3).prefix(3)
            let line = digits.suffix(4)
            return "(\(area)) \(prefix)-\(line)"
        }
        return phone
    }
}

// MARK: - Map Sheet View

@available(iOS 17.0, macOS 14.0, *)
struct MapSheetView: View {
    // Explicitly passed POIs/sessions (snapshot when map opens)
    let pois: [POI]
    let sessions: [NarrationSession]

    let currentLocation: GeoLocation?
    @Binding var showMap: Bool
    let tourManager: AudioTourManager

    // Track introducingPOIIndex via NotificationCenter (workaround for broken @Observable across sheets)
    @State private var introducingPOIIndex: Int? = nil

    var body: some View {
        let currentIndex = tourManager.currentSessionIndex

        let _ = print("🗺️ 🚨 MapSheetView.body RENDERING: pois=\(pois.count), sessions=\(sessions.count), currentIdx=\(currentIndex), introducing=\(String(describing: introducingPOIIndex))")

        NavigationStack {
            #if canImport(MapKit)
            TourMapView(
                pois: pois,
                sessions: sessions,
                introducingPOIIndex: introducingPOIIndex,
                currentSessionIndex: currentIndex,
                currentLocation: currentLocation
            )
            .navigationTitle("Tour Map")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        // Pause the tour when Done is clicked
                        Task {
                            await tourManager.pauseResume()
                        }
                        showMap = false
                    }
                }
            }
            #else
            Text("Map not available on this platform")
                .padding()
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("IntroducingPOIIndexChanged"))) { notification in
            print("🗺️ MapSheetView: Received notification")
            if let index = notification.userInfo?["index"] as? Int {
                print("🗺️ MapSheetView: Updating introducingPOIIndex to \(index)")
                introducingPOIIndex = index
            } else {
                print("🗺️ MapSheetView: Updating introducingPOIIndex to nil")
                introducingPOIIndex = nil
            }
        }
    }
}

#Preview {
    AudioTourView()
        .environment(AppState())
}
