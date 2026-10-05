#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
import SwiftUI

/// Everything drawn on the map, bottom to top: photo pins and
/// clusters, todo pins, the user's location, and the open callout.
struct MapLayers<Callout: View>: MapContent {
    let clusters: [MapCluster]
    let todoPins: [TodoPin]
    let draggedPin: DraggedPin?
    let provisionalPin: CLLocationCoordinate2D?
    let userLocation: CLLocationCoordinate2D?
    let callout: MapCalloutContent?
    let proxy: MapProxy
    let onMoveChanged: (TodoPin, CLLocationCoordinate2D) -> Void
    let onMoveEnded: (TodoPin) -> Void
    let onTapPin: (String) -> Void
    let onMovePinToCenter: (TodoPin) -> Void
    let photoLabel: (String) -> String
    @ViewBuilder let calloutView: (MapCalloutContent) -> Callout

    var body: some MapContent {
        ForEach(clusters) { cluster in
            if cluster.isSingle {
                MapAnnotations.photo(
                    PhotoMapPin(photoId: cluster.photoIds[0], coordinate: cluster.coordinate),
                    label: photoLabel(cluster.photoIds[0]), onTap: onTapPin
                )
            } else {
                MapAnnotations.cluster(cluster, onTap: onTapPin)
            }
        }
        TodoPinsMapContent(
            pins: todoPins, draggedPin: draggedPin, provisionalPin: provisionalPin, proxy: proxy,
            onMoveChanged: onMoveChanged, onMoveEnded: onMoveEnded, onTap: onTapPin,
            onMoveToCenter: onMovePinToCenter
        )
        if let userLocation {
            MapAnnotations.userMarker(at: userLocation)
        }
        if let callout {
            // Its own annotation, declared last, so it floats above
            // the pin it belongs to. Tagged so a tap inside it reads
            // as "keep this selection" rather than a deselect.
            Annotation("", coordinate: callout.coordinate, anchor: .bottom) {
                calloutView(callout).padding(.bottom, 24)
            }
            .annotationTitles(.hidden)
            .tag("callout:\(callout.tag)")
        }
    }
}
#endif
