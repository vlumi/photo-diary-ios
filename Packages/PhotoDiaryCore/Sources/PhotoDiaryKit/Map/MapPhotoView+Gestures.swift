#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
import SwiftUI

// MARK: - Location following

extension MapPhotoView {
    /// Centers on the fix already in hand so the button responds at
    /// once, then asks for a fresh one.
    func toggleFollow() {
        if follow.isOn {
            follow.stop()
            return
        }
        // Following nothing would leave the button on with no position.
        guard !locator.isDenied else {
            locator.locate()
            return
        }
        follow.start()
        if let here = locator.lastLocation {
            let meters = FollowState.locateMeters(
                current: currentMeters, closeUp: Self.closeUpMeters)
            withAnimation { frame(here, meters: meters) }
        }
        locator.locate()
    }

    func keepUp(with coord: CLLocationCoordinate2D) {
        withAnimation { frame(coord, meters: currentMeters) }
        follow.recentered()
    }

    var currentMeters: CLLocationDistance {
        guard let currentRegion else { return Self.closeUpMeters }
        return MapRegion(currentRegion).shortSpanMeters
    }
}

// MARK: - Pins ahead of a pan

extension MapPhotoView {
    /// Runs every frame of a pan or pinch, so it only rebuilds once the
    /// camera nears the edge of the area the pins were built for.
    func cameraMoving(_ region: MKCoordinateRegion, pins: [PhotoMapPin]) {
        guard let clusteredRegion,
            MapClustering.isStale(
                clustered: clusteredRegion, for: MapRegion(region), margin: clusteredMargin)
        else { return }
        recluster(pins: pins, region: region)
    }
}

// MARK: - Adding and moving pins without a gesture

extension MapPhotoView {
    func openPendingAdd() {
        guard let center = addingAt else { return }
        addingAt = nil
        placing = center
        editorPresentation = .create(center)
    }

    func movePinToCenter(_ pin: TodoPin) {
        guard let center = currentRegion?.center else { return }
        try? TodoPinStore(context: modelContext).move(
            pin, latitude: center.latitude, longitude: center.longitude)
    }

    var showsPinHint: Bool {
        !pinHintSeen && todoPins.isEmpty && !stageCues.isStaged
    }
}

// MARK: - Staged launch

extension MapPhotoView {
    /// Run once the camera first settles: MapKit drops a selection made
    /// before the map is up.
    func takeStagedCues() {
        if var tag = stageCues.takeSelection() {
            if tag == "todo", let first = todoPins.first { tag = "todo:\(first.id.uuidString)" }
            ownTap = OwnTap(tag: tag, at: Date(), handled: false)
            selection = tag
        }
        if stageCues.takeSheet(.pins) { showingList = true }
    }
}

// MARK: - Selection

extension MapPhotoView {
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

    /// Tags are "kind:id" so one selection binding covers every layer.
    /// Returns whether the selection should stay (a callout is showing).
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
