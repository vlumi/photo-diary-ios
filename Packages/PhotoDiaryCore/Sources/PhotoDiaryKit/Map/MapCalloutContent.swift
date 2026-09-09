#if canImport(MapKit) && canImport(UIKit)
import CoreLocation

/// A selected pin's callout: photos (one, or a pile) or a todo note.
struct MapCalloutContent {
    enum Kind {
        case photos([Photo])
        case todo(TodoPin)
    }
    let tag: String
    let coordinate: CLLocationCoordinate2D
    let kind: Kind

    /// The callout for a selection tag, resolved against the current
    /// clusters; nil once reclustering has moved it out of view.
    static func resolve(
        tag: String?, clusters: [MapCluster], photosById: [String: Photo],
        todoPins: [TodoPin], moving: MovingPin?
    ) -> MapCalloutContent? {
        guard let tag else { return nil }
        let parts = tag.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "photo":
            guard let photo = photosById[parts[1]],
                let cluster = clusters.first(where: { $0.isSingle && $0.photoIds[0] == parts[1] })
            else { return nil }
            return MapCalloutContent(
                tag: tag, coordinate: cluster.coordinate, kind: .photos([photo]))
        case "cluster":
            guard let cluster = clusters.first(where: { $0.id == parts[1] }) else { return nil }
            let photos = cluster.photoIds.compactMap { photosById[$0] }
            return MapCalloutContent(
                tag: tag, coordinate: cluster.coordinate, kind: .photos(photos))
        case "todo":
            guard let pin = todoPins.first(where: { $0.id.uuidString == parts[1] }) else {
                return nil
            }
            let coordinate = moving?.id == pin.id ? moving!.coordinate : pin.coordinate
            return MapCalloutContent(tag: tag, coordinate: coordinate, kind: .todo(pin))
        default:
            return nil
        }
    }
}
#endif
