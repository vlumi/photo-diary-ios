#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
import SwiftUI

/// Everything drawn on the map, bottom to top: photo pins and
/// clusters, todo pins, the user's location, and the open callout.
struct MapLayers<Callout: View>: MapContent {
    let clusters: [MapCluster]
    let todoPins: [TodoPin]
    let moving: MovingPin?
    let placing: CLLocationCoordinate2D?
    let userLocation: CLLocationCoordinate2D?
    let callout: MapCalloutContent?
    let proxy: MapProxy
    let onMoveChanged: (TodoPin, CLLocationCoordinate2D) -> Void
    let onMoveEnded: (TodoPin) -> Void
    @ViewBuilder let calloutView: (MapCalloutContent) -> Callout

    var body: some MapContent {
        ForEach(clusters) { cluster in
            if cluster.isSingle {
                MapAnnotations.photo(
                    PhotoMapPin(photoId: cluster.photoIds[0], coordinate: cluster.coordinate)
                )
            } else {
                MapAnnotations.cluster(cluster)
            }
        }
        TodoPinsMapContent(
            pins: todoPins, moving: moving, placing: placing, proxy: proxy,
            onMoveChanged: onMoveChanged, onMoveEnded: onMoveEnded
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
