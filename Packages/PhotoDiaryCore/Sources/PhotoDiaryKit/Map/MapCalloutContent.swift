#if canImport(MapKit) && canImport(UIKit)
import CoreLocation

/// A selected pin's callout: photos (one, or a pile) or a todo note.
struct MapCalloutContent {
    enum Kind {
        case photos([Photo])
        case todo(TodoPin)
    }
    let selection: MapPinSelection
    let coordinate: CLLocationCoordinate2D
    let kind: Kind

    /// Resolved against the current clusters; nil once reclustering has
    /// moved the selection out of view.
    static func resolve(
        _ selection: MapPinSelection?, clusters: [MapCluster], photosById: [String: Photo],
        todoPins: [TodoPin], draggedPin: DraggedPin?
    ) -> MapCalloutContent? {
        switch selection {
        case .photo(let id):
            guard let photo = photosById[id],
                let cluster = clusters.first(where: { $0.isSingle && $0.photoIds[0] == id })
            else { return nil }
            return MapCalloutContent(
                selection: .photo(id), coordinate: cluster.coordinate, kind: .photos([photo]))
        case .cluster(let id):
            guard let cluster = clusters.first(where: { $0.id == id }) else { return nil }
            let photos = cluster.photoIds.compactMap { photosById[$0] }
            return MapCalloutContent(
                selection: .cluster(id), coordinate: cluster.coordinate, kind: .photos(photos))
        case .todo(let id):
            guard let pin = todoPins.first(where: { $0.id == id }) else { return nil }
            let coordinate = draggedPin?.id == pin.id ? draggedPin!.coordinate : pin.coordinate
            return MapCalloutContent(selection: .todo(id), coordinate: coordinate, kind: .todo(pin))
        case .callout, nil:
            return nil
        }
    }
}
#endif
