#if canImport(CoreLocation) && canImport(UIKit)
import CoreLocation
import Observation
import UIKit

/// Tracks only while the map is on screen, with a 10 m distance filter:
/// no background draw and no jitter from GPS noise.
@MainActor
@Observable
public final class UserLocationController: NSObject {
    public private(set) var authorization: CLAuthorizationStatus
    public private(set) var lastLocation: CLLocationCoordinate2D?
    public private(set) var lastError: String?
    /// Bumped when the fix a locate() asked for lands. A counter, not the
    /// coordinate: a stationary device gets the same fix back, and an
    /// unchanged value never fires onChange.
    public private(set) var freshFix = 0
    public private(set) var updateCount = 0
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

    /// With Best accuracy a fresh fix can take seconds, which is why the
    /// map centers on `lastLocation` first.
    public func locate() {
        lastError = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            fixRequested = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            lastError = String(localized: "Location permission denied. Enable it in Settings.")
        case .authorizedWhenInUse, .authorizedAlways:
            fixRequested = true
            manager.requestLocation()
        @unknown default:
            lastError = String(localized: "Unknown location authorization state.")
        }
    }

    public var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    public func dismissError() {
        lastError = nil
    }

    private var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }
}

extension UserLocationController: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        guard isAuthorized else { return }
        lastError = nil
        if tracking { manager.startUpdatingLocation() }
        if fixRequested { manager.requestLocation() }
    }

    public func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        guard let last = locations.last else { return }
        lastLocation = last.coordinate
        updateCount += 1
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
