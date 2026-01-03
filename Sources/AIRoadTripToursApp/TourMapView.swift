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
    let currentLocation: GeoLocation?
    let currentPOIIndex: Int
    let sessions: [NarrationSession]

    @State private var region: MKCoordinateRegion
    @State private var selectedPOI: POI?

    public init(
        pois: [POI],
        currentLocation: GeoLocation?,
        currentPOIIndex: Int = 0,
        sessions: [NarrationSession] = []
    ) {
        self.pois = pois
        self.currentLocation = currentLocation
        self.currentPOIIndex = currentPOIIndex
        self.sessions = sessions

        // Initialize region centered on current location or first POI
        if let location = currentLocation {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            ))
        } else if let firstPOI = pois.first {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: firstPOI.location.latitude,
                    longitude: firstPOI.location.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            ))
        }
    }

    public var body: some View {
        ZStack {
            #if os(iOS)
            Map(coordinateRegion: $region, annotationItems: annotations) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    item.view
                }
            }
            #else
            Text("Map view requires iOS")
                .foregroundStyle(.secondary)
            #endif
        }
        .overlay(alignment: .bottom) {
            if let selected = selectedPOI {
                POIInfoCard(poi: selected)
                    .padding()
                    .background(.ultraThinMaterial)
            }
        }
    }

    private var annotations: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []

        // Current location
        if let location = currentLocation {
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
        for (index, poi) in pois.enumerated() {
            items.append(MapAnnotationItem(
                id: poi.id.uuidString,
                coordinate: poi.location.coordinate,
                view: AnyView(
                    POIMarker(
                        poi: poi,
                        index: index,
                        isCurrent: index == currentPOIIndex,
                        isPassed: index < currentPOIIndex,
                        phase: getPhase(for: index)
                    )
                    .onTapGesture {
                        selectedPOI = poi
                    }
                )
            ))
        }

        return items
    }

    private func getPhase(for index: Int) -> NarrationPhase? {
        guard index < sessions.count else { return nil }
        return sessions[index].currentPhase
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

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(poi.name)
                        .font(.headline)

                    Text(poi.category.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

            if let description = poi.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
        TourMapView(
            pois: [
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
            ],
            currentLocation: GeoLocation(latitude: 45.5152, longitude: -122.6784),
            currentPOIIndex: 0
        )
    }
    #else
    Text("Map not available")
    #endif
}
