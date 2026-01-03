import CoreLocation
import AIRoadTripToursCore

/// Location service for getting user's current location.
@MainActor
public class LocationService: NSObject, ObservableObject {
    @Published public var currentLocation: GeoLocation?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var error: Error?

    private let locationManager = CLLocationManager()

    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update every 100 meters
    }

    public func requestLocationPermission() {
        authorizationStatus = locationManager.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            error = LocationError.permissionDenied
        @unknown default:
            break
        }
    }

    public func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    public func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Capture values outside Task to avoid data races
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let altitude = location.altitude

        Task { @MainActor in
            currentLocation = GeoLocation(
                latitude: latitude,
                longitude: longitude,
                altitude: altitude
            )
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Capture status outside Task to avoid data races
        let status = manager.authorizationStatus

        Task { @MainActor in
            authorizationStatus = status

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                startUpdatingLocation()
            case .denied, .restricted:
                error = LocationError.permissionDenied
                stopUpdatingLocation()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}

public enum LocationError: Error, LocalizedError {
    case permissionDenied
    case locationUnavailable

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied. Please enable location access in Settings."
        case .locationUnavailable:
            return "Unable to determine your location. Please try again."
        }
    }
}
