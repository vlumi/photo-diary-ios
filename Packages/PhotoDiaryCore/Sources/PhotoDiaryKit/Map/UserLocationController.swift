#if canImport(CoreLocation) && canImport(UIKit)
import CoreLocation
import Observation
import UIKit

/// CLLocationManager wrapper for the map: keeps `lastLocation` fresh
/// while the map is on screen (so the marker follows the user) and
/// serves the locate button: the map centres on `lastLocation` at once
/// and `freshFix` ticks when the fix requested by the tap arrives.
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
    /// Bumped once per locate() when its requested fix lands, so the
    /// map can re-centre on that one update and not on later ones. A
    /// counter, not the coordinate: a stationary device gets the same
    /// fix back, and a same-value change would never fire onChange.
    public private(set) var freshFix = 0
    private var fixRequested = false

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

    /// Ask for permission if not yet decided, then request one fresh
    /// fix, reported through `freshFix`. With Best accuracy that can
    /// take several seconds, which is why the map centres on the known
    /// `lastLocation` first rather than waiting for this. If permission
    /// is denied, sets lastError for the banner.
    public func locate() {
        lastError = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            fixRequested = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            lastError = "Location permission denied. Enable it in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            fixRequested = true
            manager.requestLocation()
        @unknown default:
            lastError = "Unknown location authorization state."
        }
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
        if fixRequested { manager.requestLocation() }
    }

    public func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        guard let last = locations.last else { return }
        lastLocation = last.coordinate
        if fixRequested {
            fixRequested = false
            freshFix += 1
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fixRequested = false
        lastError = error.localizedDescription
    }
}
#endif
