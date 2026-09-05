#if canImport(CoreLocation) && canImport(UIKit)
import CoreLocation
import Observation
import UIKit

/// Thin wrapper around CLLocationManager for the map surface's
/// locate-me button. Owns the authorization + one-shot location
/// request; SwiftUI reads authorization + lastLocation as Observable
/// state.
///
/// One-shot rather than continuous updates on purpose: the button
/// centres the map once, no background power draw. Reset the
/// last-known-location after use so a subsequent tap forces a fresh
/// read.
@MainActor
@Observable
public final class UserLocationController: NSObject {
    public private(set) var authorization: CLAuthorizationStatus
    public private(set) var lastLocation: CLLocationCoordinate2D?
    public private(set) var lastError: String?

    private let manager: CLLocationManager

    public override init() {
        self.manager = CLLocationManager()
        self.authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    /// Ask for permission if not yet decided, then request one
    /// location. If permission is denied, sets lastError so the UI
    /// can surface it.
    public func locate() {
        lastError = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            // requestLocation fires after permission lands (see
            // locationManagerDidChangeAuthorization below).
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            lastError = "Location permission denied. Enable it in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        @unknown default:
            lastError = "Unknown location authorization state."
        }
    }

    /// Clear the last-known location so a subsequent locate() forces
    /// a fresh read (the map surface calls this after centring).
    public func clearLast() {
        lastLocation = nil
    }
}

extension UserLocationController: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        // If we just gained permission (locate() started the flow),
        // fire the one-shot request now.
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.requestLocation()
        }
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
