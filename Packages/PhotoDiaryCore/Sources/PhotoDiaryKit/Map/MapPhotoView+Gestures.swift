#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
import SwiftUI

// MARK: - Location following

extension MapPhotoView {
    /// Switching on centers on the fix already in hand so the button
    /// responds at once — zooming in to street level, never out — and
    /// asks for a fresh one. Switching off just stops following.
    func toggleFollow() {
        if follow.isOn {
            follow.stop()
            return
        }
        follow.start()
        if let here = locator.lastLocation {
            withAnimation { frame(here, meters: min(currentMeters, Self.closeUpMeters)) }
        }
        locator.locate()
    }

    /// Following: move to the position at the zoom the user has.
    func keepUp(with coord: CLLocationCoordinate2D) {
        withAnimation { frame(coord, meters: currentMeters) }
        follow.recentered()
    }

    var currentMeters: CLLocationDistance {
        guard let currentRegion else { return Self.closeUpMeters }
        return MapRegion(currentRegion).shortSpanMeters
    }
}

// MARK: - Todo pin gestures

extension MapPhotoView {
    func placementGesture(_ proxy: MapProxy) -> some Gesture {
        MapTouchGestures(
            proxy: proxy, isMovingPin: { moving != nil },
            pressPoint: $pressPoint, placing: $placing,
            onPlaced: { editorPresentation = .create($0) },
            onTap: {
                // A tap on empty map closes the callout; one a pin or the
                // callout just took is theirs.
                if let ownTap, Date().timeIntervalSince(ownTap.at) < 0.3 { return }
                selection = nil
            }
        ).gesture
    }

    func finishMove(_ pin: TodoPin) {
        if let moving, moving.id == pin.id {
            try? TodoPinStore(context: modelContext).move(
                pin, latitude: moving.coordinate.latitude, longitude: moving.coordinate.longitude)
        }
        moving = nil
    }
}
#endif
