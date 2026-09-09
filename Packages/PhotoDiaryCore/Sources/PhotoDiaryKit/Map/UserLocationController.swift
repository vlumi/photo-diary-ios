#if canImport(CoreLocation) && canImport(UIKit)
import CoreLocation
import Observation
import UIKit

/// CLLocationManager wrapper for the map: keeps `lastLocation` fresh
/// while the map is on screen (so the marker follows the user) and
/// serves the locate button, which centres the camera on the next fix.
///
/// Tracking runs only between startTracking() / stopTracking() — the
/// map calls them on appear / disappear — with a 10 m distance filter,
/// so there is no background draw and no jitter from GPS noise.
@MainActor
@Observable
public final class UserLocationController: NSObject {
    public private(set) var authorization: CLAuthorizationStatus
    public private(set) var lastLocation: CLLocationCoordinate2D?
    public private(set) var lastError: String?
    /// Set by locate(); the map consumes it when a fix arrives so the
    /// camera moves once, not on every subsequent update.
    public private(set) var centerRequested = false

    private let manager: CLLocationManager
    private var tracking = false

    public override init() {
        self.manager = CLLocationManager()
        self.authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
    }

    public func startTracking() {
        tracking = true
        if isAuthorized { manager.startUpdatingLocation() }
    }

    public func stopTracking() {
        tracking = false
        manager.stopUpdatingLocation()
    }

    /// Ask for permission if not yet decided, then centre on the next
    /// fix. If permission is denied, sets lastError for the banner.
    public func locate() {
        lastError = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            centerRequested = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            lastError = "Location permission denied. Enable it in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            centerRequested = true
            manager.requestLocation()
        @unknown default:
            lastError = "Unknown location authorization state."
        }
    }

    /// The coordinate to centre on if locate() asked for it, once.
    public func consumeCenterRequest() -> CLLocationCoordinate2D? {
        guard centerRequested, let lastLocation else { return nil }
        centerRequested = false
        return lastLocation
    }

    private var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }
}

extension UserLocationController: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        guard isAuthorized else { return }
        if tracking { manager.startUpdatingLocation() }
        if centerRequested { manager.requestLocation() }
    }

    public func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        guard let last = locations.last else { return }
        lastLocation = last.coordinate
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
    }
}
#endif
