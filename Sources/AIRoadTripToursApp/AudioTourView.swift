import SwiftUI
import AIRoadTripToursCore
import AIRoadTripToursServices

public struct AudioTourView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var locationService = LocationService()
    @State private var showMap = false
    @State private var currentWeather: WeatherForecast?
    @State private var isLoadingWeather = false

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

                    // Start Tour Button (only show when tour is not prepared)
                    if !tourManager.isPrepared {
                        Button {
                            Task { await startAudioTour() }
                        } label: {
                            Label(
                                appState.selectedPOIs.isEmpty ? "Start Audio Tour (All Nearby POIs)" : "Start Tour (\(appState.selectedPOIs.count) Selected)",
                                systemImage: "play.circle.fill"
                            )
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canStartTour ? .green : .gray)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(!canStartTour)

                        if locationService.currentLocation == nil {
                            Text("Enable location access to start audio tour")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Show active tour view when playing
                if tourManager.playbackState == .playing || tourManager.playbackState == .paused {
                    ActiveTourView(
                        narration: tourManager.currentNarration!,
                        images: tourManager.getImagesForCurrentPOI()
                    )
                    .frame(height: 300)
                    .cornerRadius(16)
                    .padding(.horizontal)
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
            .sheet(isPresented: $showMap) {
                NavigationStack {
                    #if canImport(MapKit)
                    if #available(iOS 17.0, macOS 14.0, *) {
                        TourMapView(
                            pois: tourManager.currentPOIs,
                            currentLocation: locationService.currentLocation,
                            currentPOIIndex: tourManager.currentSessionIndex,
                            sessions: tourManager.sessions
                        )
                        .navigationTitle("Tour Map")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button("Done") {
                                    showMap = false
                                }
                            }
                        }
                    } else {
                        Text("Map requires iOS 17.0+")
                            .padding()
                    }
                    #else
                    Text("Map not available on this platform")
                        .padding()
                    #endif
                }
            }
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
        guard let userLocation = locationService.currentLocation else {
            return
        }

        // Start generating immediately with loading state
        tourManager.isGenerating = true

        Task {
            do {
                // Use selected POIs if any, otherwise find nearby POIs
                let pois: [POI]
                if !appState.selectedPOIs.isEmpty {
                    // Use selected POIs and optimize route
                    let optimizer = RouteOptimizer()
                    pois = await optimizer.optimizeRoute(
                        startingFrom: userLocation,
                        visiting: Array(appState.selectedPOIs)
                    )
                } else {
                    // Find all nearby POIs and optimize route
                    let nearbyPOIs = try await appState.poiRepository.findNearby(
                        location: userLocation,
                        radiusMiles: 25.0,
                        categories: nil
                    )

                    let optimizer = RouteOptimizer()
                    pois = await optimizer.optimizeRoute(
                        startingFrom: userLocation,
                        visiting: Array(nearbyPOIs.prefix(5))
                    )
                }

                // Start tour with manager
                await tourManager.startTour(
                    pois: pois,
                    userInterests: appState.currentUser?.interests ?? []
                )

            } catch {
                print("Error starting audio tour: \(error)")
                tourManager.isGenerating = false
            }
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

#Preview {
    AudioTourView()
        .environment(AppState())
}
