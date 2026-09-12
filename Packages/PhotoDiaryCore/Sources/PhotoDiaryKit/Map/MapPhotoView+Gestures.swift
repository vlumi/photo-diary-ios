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

// MARK: - Selection

extension MapPhotoView {
    /// The selection binding changed — from a pin's own tap gesture, or
    /// from MapKit, which reports the same tap again about half a
    /// second later after its double-tap wait.
    func selectionChanged(_ selected: String?, pins: [PhotoMapPin]) {
        if let selected, let closed = ownDeselect, selected == closed.tag,
            Date().timeIntervalSince(closed.at) < 0.7,
            (ownTap.map { $0.at < closed.at } ?? true)
        {
            selection = nil
            return
        }
        if let selected, var tap = ownTap, selected == tap.tag {
            if tap.handled, selected.hasPrefix("cluster:"),
                Date().timeIntervalSince(tap.at) < 0.7
            {
                // MapKit's echo of a cluster tap that already zoomed:
                // don't zoom twice. A photo or todo echo is harmless.
                selection = nil
                return
            }
            tap.handled = true
            ownTap = tap
        }
        guard let selected else {
            calloutFor = nil
            return
        }
        if !handleSelection(selected, pins: pins) { selection = nil }
    }

    func handleSelection(_ tag: String, pins: [PhotoMapPin]) -> Bool {
        let parts = tag.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return false }
        switch parts[0] {
        case "photo":
            calloutFor = tag
            return true
        case "cluster":
            guard let cluster = clusters.first(where: { $0.id == parts[1] }) else { return false }
            switch MapClustering.tapAction(for: cluster, pins: pins) {
            case .zoom(let region):
                calloutFor = nil
                cameraPosition = .region(MKCoordinateRegion(region))
                return false
            case .list:
                calloutFor = tag
                return true
            }
        case "callout":
            // A tap inside the callout (its thumbnail or chevrons) also
            // selects the callout annotation; keep the underlying pin
            // selected so the callout stays put.
            selection = parts[1]
            return true
        case "todo":
            calloutFor = tag
            return true
        default:
            return false
        }
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
                // callout just took is theirs. The map's touch-up arrives
                // before theirs does, so look again a moment later.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(60))
                    if let ownTap, Date().timeIntervalSince(ownTap.at) < 0.3 { return }
                    if let current = selection {
                        ownDeselect = OwnTap(tag: current, at: Date(), handled: true)
                    }
                    selection = nil
                }
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
