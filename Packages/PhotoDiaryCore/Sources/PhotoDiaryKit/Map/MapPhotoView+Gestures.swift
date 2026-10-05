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
        provisionalPin = center
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
        let staged: MapPinSelection? =
            switch stageCues.takeSelection() {
            case .firstTodo: todoPins.first.map { .todo($0.id) }
            case .pin(let pin): pin
            case nil: nil
            }
        if let staged {
            ownTap = OwnTap(selection: staged, at: Date(), handled: false)
            selection = staged
        }
        if stageCues.takeSheet(.pins) { showingList = true }
    }
}

// MARK: - Selection

extension MapPhotoView {
    // MapKit reports a tap as a selection again ~0.6 s later, after its
    // double-tap wait: within `selectionEcho` the echo is dropped, and the
    // map's own tap stands down for `ownTapClaim` after a pin took it.
    static let selectionEcho: TimeInterval = 0.7
    static let ownTapClaim: TimeInterval = 0.3

    func selectionChanged(_ selected: MapPinSelection?, pins: [PhotoMapPin]) {
        if let selected, let closed = ownDeselect, selected == closed.selection,
            Date().timeIntervalSince(closed.at) < Self.selectionEcho,
            (ownTap.map { $0.at < closed.at } ?? true)
        {
            selection = nil
            return
        }
        if let selected, var tap = ownTap, selected == tap.selection {
            if tap.handled, selected.isCluster,
                Date().timeIntervalSince(tap.at) < Self.selectionEcho
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
            calloutSelection = nil
            return
        }
        if !showsCallout(for: selected, pins: pins) { selection = nil }
    }

    /// Returns whether the selection should stay (a callout is showing).
    func showsCallout(for selected: MapPinSelection, pins: [PhotoMapPin]) -> Bool {
        switch selected {
        case .photo, .todo:
            calloutSelection = selected
            return true
        case .cluster(let id):
            guard let cluster = clusters.first(where: { $0.id == id }) else { return false }
            switch MapClustering.tapAction(for: cluster, pins: pins) {
            case .zoom(let region):
                calloutSelection = nil
                cameraPosition = .region(MKCoordinateRegion(region))
                return false
            case .list:
                calloutSelection = selected
                return true
            }
        case .callout(let pin):
            // A tap inside the callout (its thumbnail or chevrons) selects
            // the callout's own annotation; the pin stays selected so the
            // callout stays put.
            selection = pin
            return true
        }
    }

}

// MARK: - Todo pin gestures

extension MapPhotoView {
    func touchGestures(_ proxy: MapProxy) -> some Gesture {
        MapTouchGestures(
            proxy: proxy, isDraggingPin: { draggedPin != nil },
            pressPoint: $pressPoint, provisionalPin: $provisionalPin,
            onPlaced: { editorPresentation = .create($0) },
            onTap: {
                // A tap on empty map closes the callout; one a pin or the
                // callout just took is theirs. The map's touch-up arrives
                // before theirs does, so look again a moment later.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(60))
                    if let ownTap, Date().timeIntervalSince(ownTap.at) < Self.ownTapClaim { return }
                    if let current = selection {
                        ownDeselect = OwnTap(selection: current, at: Date(), handled: true)
                    }
                    selection = nil
                }
            }
        ).gesture
    }

    func finishMove(_ pin: TodoPin) {
        if let draggedPin, draggedPin.id == pin.id {
            try? TodoPinStore(context: modelContext).move(
                pin, latitude: draggedPin.coordinate.latitude,
                longitude: draggedPin.coordinate.longitude)
        }
        draggedPin = nil
    }
}
#endif
