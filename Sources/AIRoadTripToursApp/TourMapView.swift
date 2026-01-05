import SwiftUI
#if canImport(MapKit)
import MapKit
#endif
import AIRoadTripToursCore

/// Map view showing tour route with POIs and current location.
#if canImport(MapKit)
@available(iOS 17.0, macOS 14.0, *)
public struct TourMapView: View {
    let pois: [POI]
    let sessions: [NarrationSession]
    let introducingPOIIndex: Int?
    let currentSessionIndex: Int
    let currentLocation: GeoLocation?

    @State private var region: MKCoordinateRegion
    @State private var selectedPOI: POI?
    @State private var showLegend = false
    @State private var cameraMode: CameraMode = .fitAll
    @State private var routeCoordinates: [CLLocationCoordinate2D] = [] // Actual navigation route

    enum CameraMode {
        case fitAll
        case followUser
        case currentPOI
        case introducing
    }

    public init(
        pois: [POI],
        sessions: [NarrationSession],
        introducingPOIIndex: Int?,
        currentSessionIndex: Int = 0,
        currentLocation: GeoLocation?
    ) {
        print("🗺️ TourMapView.init() pois=\(pois.count), sessions=\(sessions.count), currentIdx=\(currentSessionIndex)")
        self.pois = pois
        self.sessions = sessions
        self.introducingPOIIndex = introducingPOIIndex
        self.currentSessionIndex = currentSessionIndex
        self.currentLocation = currentLocation

        // Initialize with default region (will update when POIs are loaded)
        _region = State(initialValue: MKCoordinateRegion(
            center: currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        ))
    }

    public var body: some View {
        print("🗺️ TourMapView.body: pois=\(pois.count), sessions=\(sessions.count), currentIdx=\(currentSessionIndex), introducing=\(String(describing: introducingPOIIndex))")

        return ZStack {
            #if os(iOS)
            Map(coordinateRegion: $region, annotationItems: annotationsWithHighlight(introducingIndex: introducingPOIIndex)) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    item.view
                }
            }
            .overlay {
                // Route polyline overlay
                RoutePolylineOverlay(
                    pois: pois,
                    currentLocation: currentLocation,
                    currentPOIIndex: currentSessionIndex,
                    region: region,
                    routeCoordinates: routeCoordinates
                )
            }
            #else
            Text("Map view requires iOS")
                .foregroundStyle(.secondary)
            #endif

            // Map controls
            VStack {
                HStack {
                    Spacer()

                    VStack(spacing: 12) {
                        // Legend button
                        Button {
                            showLegend.toggle()
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }

                        // Fit all button
                        Button {
                            fitAllPOIs()
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }

                        // Recenter on current location button
                        if currentLocation != nil {
                            Button {
                                recenterOnCurrentLocation()
                            } label: {
                                Image(systemName: "location.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                        }

                        // Center on current POI button
                        if currentSessionIndex < pois.count {
                            Button {
                                centerOnCurrentPOI()
                            } label: {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.purple)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                        }
                    }
                    .padding()
                }

                Spacer()
            }
        }
        .overlay(alignment: .bottom) {
            if let selected = selectedPOI {
                POIInfoCard(
                    poi: selected,
                    currentLocation: currentLocation,
                    session: getSession(for: selected)
                )
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showLegend) {
            PhaseLegendView()
        }
        .onChange(of: currentLocation) { oldValue, newValue in
            if cameraMode == .followUser, newValue != nil {
                recenterOnCurrentLocation()
            }
        }
        .onChange(of: currentSessionIndex) { oldValue, newValue in
            print("🗺️ Map: currentSessionIndex changed from \(oldValue) to \(newValue)")
            if cameraMode == .currentPOI {
                centerOnCurrentPOI()
            }
        }
        .onChange(of: pois) { oldValue, newValue in
            print("🗺️ Map: POIs changed from \(oldValue.count) to \(newValue.count)")
            if !newValue.isEmpty && cameraMode == .fitAll {
                fitAllPOIs()
            }
        }
        .onChange(of: introducingPOIIndex) { oldValue, newValue in
            print("🗺️ Map.onChange: introducingPOIIndex changed from \(String(describing: oldValue)) to \(String(describing: newValue)), pois.count=\(pois.count)")

            // Animate zoom based on introduction state
            if let index = newValue, index < pois.count {
                // Zoom to this POI for introduction
                print("🗺️ Map.onChange: ✅ Condition met - Starting zoom to POI \(index)")
                zoomToIntroducingPOI(index: index)
            } else if let index = newValue {
                print("🗺️ Map.onChange: ❌ Condition failed - index \(index) >= pois.count \(pois.count)")
            } else if oldValue != nil && newValue == nil {
                // Zoom back out to full tour view
                print("🗺️ Map.onChange: Zooming back out to full view")
                fitAllPOIs()
            } else {
                print("🗺️ Map.onChange: No action taken")
            }
        }
        .task {
            print("🗺️ Map.task: Started")

            // Fit all POIs on initial load
            if !pois.isEmpty {
                print("🗺️ Map.task: Performing initial zoom to fit all POIs")
                fitAllPOIs()

                // Fetch actual navigation routes in separate task to avoid blocking
                Task {
                    print("🗺️ Map.task: Fetching navigation routes (background)")
                    await fetchNavigationRoutes()
                    print("🗺️ Map.task: Navigation routes fetch completed")
                }
            }
        }
    }

    private func fitAllPOIs() {
        print("🗺️ fitAllPOIs() called")
        cameraMode = .fitAll
        let coordinates = pois.map { $0.location.coordinate }
        let allCoordinates = currentLocation != nil ? coordinates + [currentLocation!.coordinate] : coordinates

        guard !allCoordinates.isEmpty else { return }

        let mapRect = allCoordinates.reduce(MKMapRect.null) { rect, coordinate in
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            return rect.union(pointRect)
        }

        let paddedRect = mapRect.insetBy(dx: -mapRect.size.width * 0.2, dy: -mapRect.size.height * 0.2)
        print("🗺️ Animating to region: center=(\(MKCoordinateRegion(paddedRect).center.latitude), \(MKCoordinateRegion(paddedRect).center.longitude))")
        withAnimation(.easeInOut(duration: 1.5)) {
            region = MKCoordinateRegion(paddedRect)
        }
    }

    private func recenterOnCurrentLocation() {
        guard let location = currentLocation else { return }
        cameraMode = .followUser
        withAnimation {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }

    private func centerOnCurrentPOI() {
        guard currentSessionIndex < pois.count else { return }
        cameraMode = .currentPOI
        let poi = pois[currentSessionIndex]
        withAnimation {
            region = MKCoordinateRegion(
                center: poi.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
    }

    private func zoomToIntroducingPOI(index: Int) {
        guard index < pois.count else {
            print("🗺️ ❌ zoomToIntroducingPOI: index \(index) out of bounds (pois.count = \(pois.count))")
            return
        }
        cameraMode = .introducing
        let poi = pois[index]
        print("🗺️ zoomToIntroducingPOI(\(index)): Zooming to \(poi.name) at (\(poi.location.latitude), \(poi.location.longitude))")
        withAnimation(.easeInOut(duration: 1.5)) {
            region = MKCoordinateRegion(
                center: poi.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003) // Very tight street-level zoom
            )
        }
        print("🗺️ Region updated to: center=(\(region.center.latitude), \(region.center.longitude)), span=(\(region.span.latitudeDelta), \(region.span.longitudeDelta))")
    }

    private func getSession(for poi: POI) -> NarrationSession? {
        sessions.first { $0.poi.id == poi.id }
    }

    private func annotationsWithHighlight(introducingIndex: Int?) -> [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []

        // Current location
        if let location = currentLocation {
            print("🗺️ annotations: Adding current location marker at (\(location.latitude), \(location.longitude))")
            items.append(MapAnnotationItem(
                id: "current",
                coordinate: location.coordinate,
                view: AnyView(
                    ZStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 20, height: 20)
                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 20, height: 20)
                    }
                )
            ))
        }

        // POI markers
        print("🗺️ annotations: Creating markers for \(pois.count) POIs, introducingIndex=\(String(describing: introducingIndex))")
        for (index, poi) in pois.enumerated() {
            print("🗺️ annotations: POI \(index): \(poi.name) at (\(poi.location.latitude), \(poi.location.longitude))")

            // Only highlight a POI when it's being introduced
            // Don't highlight based on currentSessionIndex - that's for tour progress, not visual highlighting
            let isHighlighted = (introducingIndex == index)

            items.append(MapAnnotationItem(
                id: poi.id.uuidString,
                coordinate: poi.location.coordinate,
                view: AnyView(
                    POIMarker(
                        poi: poi,
                        index: index,
                        isCurrent: isHighlighted,
                        isPassed: index < currentSessionIndex,
                        phase: getPhase(for: index)
                    )
                    .onTapGesture {
                        selectedPOI = poi
                    }
                )
            ))
        }

        print("🗺️ annotations: Returning \(items.count) total annotation items")
        return items
    }

    private func getPhase(for index: Int) -> NarrationPhase? {
        guard index < sessions.count else { return nil }
        return sessions[index].currentPhase
    }

    /// Fetches actual navigation routes from current location through all POIs
    private func fetchNavigationRoutes() async {
        var allCoordinates: [CLLocationCoordinate2D] = []

        // Build waypoints: current location -> POI1 -> POI2 -> ...
        var waypoints: [CLLocationCoordinate2D] = []
        if let location = currentLocation {
            waypoints.append(location.coordinate)
        }
        waypoints.append(contentsOf: pois.map { $0.location.coordinate })

        guard waypoints.count >= 2 else {
            print("🗺️ fetchNavigationRoutes: Not enough waypoints (\(waypoints.count))")
            return
        }

        print("🗺️ fetchNavigationRoutes: Fetching routes for \(waypoints.count) waypoints")

        // Fetch route for each segment
        for i in 0..<(waypoints.count - 1) {
            let source = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[i]))
            let destination = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[i + 1]))

            let request = MKDirections.Request()
            request.source = source
            request.destination = destination
            request.transportType = .automobile

            do {
                let directions = MKDirections(request: request)
                let response = try await directions.calculate()

                if let route = response.routes.first {
                    // Extract coordinates from polyline
                    let pointCount = route.polyline.pointCount
                    let coordinates = route.polyline.points()
                    let coordinateArray = (0..<pointCount).map { coordinates[$0].coordinate }
                    allCoordinates.append(contentsOf: coordinateArray)
                    print("🗺️ fetchNavigationRoutes: Segment \(i) added \(pointCount) coordinates")
                }
            } catch {
                print("🗺️ fetchNavigationRoutes: Error fetching route segment \(i): \(error)")
                // Fallback to straight line for this segment
                allCoordinates.append(waypoints[i])
                if i == waypoints.count - 2 {
                    allCoordinates.append(waypoints[i + 1])
                }
            }
        }

        routeCoordinates = allCoordinates
        print("🗺️ fetchNavigationRoutes: Complete! Total coordinates: \(allCoordinates.count)")
    }
}

struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let view: AnyView
}

// MARK: - POI Marker

struct POIMarker: View {
    let poi: POI
    let index: Int
    let isCurrent: Bool
    let isPassed: Bool
    let phase: NarrationPhase?

    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Pulsing animation for current POI
                if isCurrent {
                    Circle()
                        .stroke(.blue, lineWidth: 2)
                        .frame(width: 46, height: 46)
                        .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 0.8)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                }

                Circle()
                    .fill(backgroundColor)
                    .frame(width: 40, height: 40)

                if isPassed {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                } else {
                    Text("\(index + 1)")
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                }

                if isCurrent {
                    Circle()
                        .stroke(.yellow, lineWidth: 3)
                        .frame(width: 46, height: 46)
                }
            }

            Text(poi.name)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(backgroundColor)
                .foregroundStyle(.white)
                .cornerRadius(4)
        }
        .onAppear {
            if isCurrent {
                pulseAnimation = true
            }
        }
        .onChange(of: isCurrent) { oldValue, newValue in
            pulseAnimation = newValue
        }
    }

    private var backgroundColor: Color {
        if isPassed {
            return .gray
        }

        guard let phase = phase else {
            return isCurrent ? .blue : .gray
        }

        switch phase {
        case .pending: return .gray
        case .approaching: return .orange
        case .detailed: return .blue
        case .arrival: return .green
        case .guidedTour: return .purple
        case .passed: return .gray
        }
    }
}

// MARK: - POI Info Card

struct POIInfoCard: View {
    let poi: POI
    let currentLocation: GeoLocation?
    let session: NarrationSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(poi.name)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Label(poi.category.rawValue, systemImage: "tag")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let location = currentLocation {
                            let distance = poi.location.distance(to: location)
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Label(String(format: "%.1f mi", distance), systemImage: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Button {
                    openInMaps()
                } label: {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
            }

            // Session info if available
            if let session = session {
                Divider()

                HStack {
                    // Phase badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(phaseColor(session.currentPhase))
                            .frame(width: 8, height: 8)
                        Text(phaseLabel(session.currentPhase))
                            .font(.caption)
                            .foregroundStyle(phaseColor(session.currentPhase))
                    }

                    Spacer()

                    // Distance and ETA
                    if session.distanceToPOI < 100 {
                        HStack(spacing: 12) {
                            Label(String(format: "%.1f mi", session.distanceToPOI), systemImage: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            let eta = Int(session.estimatedTimeToArrival / 60)
                            Label("\(eta) min", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let description = poi.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
    }

    private func openInMaps() {
        let coordinate = poi.location.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = poi.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func phaseColor(_ phase: NarrationPhase) -> Color {
        switch phase {
        case .pending: return .gray
        case .approaching: return .orange
        case .detailed: return .blue
        case .arrival: return .green
        case .guidedTour: return .purple
        case .passed: return .gray
        }
    }

    private func phaseLabel(_ phase: NarrationPhase) -> String {
        switch phase {
        case .pending: return "Waiting"
        case .approaching: return "Approaching"
        case .detailed: return "Learning"
        case .arrival: return "Arriving"
        case .guidedTour: return "Tour"
        case .passed: return "Passed"
        }
    }
}

// MARK: - Route Polyline Overlay

struct RoutePolylineOverlay: View {
    let pois: [POI]
    let currentLocation: GeoLocation?
    let currentPOIIndex: Int
    let region: MKCoordinateRegion
    let routeCoordinates: [CLLocationCoordinate2D] // Actual navigation route

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                print("🗺️ RoutePolylineOverlay: Canvas drawing, pois.count=\(pois.count)")

                guard !pois.isEmpty else {
                    print("🗺️ RoutePolylineOverlay: No POIs, skipping route drawing")
                    return
                }

                // Use fetched route coordinates if available, otherwise fall back to straight lines
                let coordinates = routeCoordinates.isEmpty ? fallbackCoordinates() : routeCoordinates
                print("🗺️ RoutePolylineOverlay: Drawing route with \(coordinates.count) coordinates (fetched=\(!routeCoordinates.isEmpty))")

                guard coordinates.count >= 2 else {
                    print("🗺️ RoutePolylineOverlay: Not enough coordinates (\(coordinates.count)) to draw route")
                    return
                }

                // Draw the route in segments (passed vs upcoming)
                for i in 0..<(coordinates.count - 1) {
                    let startCoord = coordinates[i]
                    let endCoord = coordinates[i + 1]

                    let startPoint = mapPointToScreen(
                        coordinate: startCoord,
                        in: geometry.size,
                        region: region
                    )

                    let endPoint = mapPointToScreen(
                        coordinate: endCoord,
                        in: geometry.size,
                        region: region
                    )

                    var path = Path()
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)

                    // Determine segment color based on progress
                    // If we have current location as first point, adjust index
                    let segmentIndex = currentLocation != nil ? i - 1 : i
                    let isPassed = segmentIndex < currentPOIIndex - 1
                    let isCurrent = segmentIndex == currentPOIIndex - 1 || (i == 0 && currentLocation != nil)

                    let lineColor: Color
                    let lineWidth: CGFloat

                    if isPassed {
                        lineColor = .gray.opacity(0.4)
                        lineWidth = 2
                    } else if isCurrent {
                        lineColor = .blue
                        lineWidth = 4
                    } else {
                        lineColor = .blue.opacity(0.6)
                        lineWidth = 3
                    }

                    // Draw the segment
                    context.stroke(
                        path,
                        with: .color(lineColor),
                        lineWidth: lineWidth
                    )
                }
                print("🗺️ RoutePolylineOverlay: Finished drawing \(coordinates.count - 1) route segments")
            }
        }
        .allowsHitTesting(false)
    }

    private func mapPointToScreen(coordinate: CLLocationCoordinate2D, in size: CGSize, region: MKCoordinateRegion) -> CGPoint {
        // Convert lat/long to screen coordinates
        let mapCenterLat = region.center.latitude
        let mapCenterLon = region.center.longitude

        let latDelta = region.span.latitudeDelta
        let lonDelta = region.span.longitudeDelta

        let x = (coordinate.longitude - (mapCenterLon - lonDelta / 2)) / lonDelta * size.width
        let y = ((mapCenterLat + latDelta / 2) - coordinate.latitude) / latDelta * size.height

        return CGPoint(x: x, y: y)
    }

    /// Fallback to straight lines if navigation routes couldn't be fetched
    private func fallbackCoordinates() -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        if let location = currentLocation {
            coordinates.append(location.coordinate)
        }
        coordinates.append(contentsOf: pois.map { $0.location.coordinate })
        return coordinates
    }
}

// MARK: - Phase Legend View

struct PhaseLegendView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LegendRow(color: .gray, label: "Waiting", description: "POI is upcoming, not yet in range")
                    LegendRow(color: .orange, label: "Approaching", description: "3-5 minutes away, teaser narration plays")
                    LegendRow(color: .blue, label: "Learning", description: "1-2 minutes away, detailed narration available")
                    LegendRow(color: .green, label: "Arriving", description: "Arrived at POI, guided tour available")
                    LegendRow(color: .purple, label: "Tour", description: "Guided tour in progress")
                    LegendRow(color: .gray, label: "Passed", description: "POI has been visited or skipped")
                } header: {
                    Text("Narration Phases")
                } footer: {
                    Text("POI marker colors indicate the current narration phase based on your location and progress through the tour.")
                }
            }
            .navigationTitle("Map Legend")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LegendRow: View {
    let color: Color
    let label: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Extensions

extension GeoLocation {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
#endif

#Preview {
    #if canImport(MapKit)
    if #available(iOS 17.0, macOS 14.0, *) {
        let previewPOIs = [
            POI(
                name: "Multnomah Falls",
                description: "Oregon's tallest waterfall",
                category: .waterfall,
                location: GeoLocation(latitude: 45.5762, longitude: -122.1158),
                tags: ["nature", "hiking"]
            ),
            POI(
                name: "Powell's Books",
                description: "World's largest independent bookstore",
                category: .shopping,
                location: GeoLocation(latitude: 45.5230, longitude: -122.6815),
                tags: ["books", "culture"]
            )
        ]

        let previewSessions = previewPOIs.map { NarrationSession(poi: $0) }

        TourMapView(
            pois: previewPOIs,
            sessions: previewSessions,
            introducingPOIIndex: nil,
            currentSessionIndex: 0,
            currentLocation: GeoLocation(latitude: 45.5152, longitude: -122.6784)
        )
    }
    #else
    Text("Map not available")
    #endif
}
