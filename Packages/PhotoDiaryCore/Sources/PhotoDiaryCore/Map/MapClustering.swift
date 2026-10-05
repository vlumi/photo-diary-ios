import CoreLocation
import Foundation

/// A map viewport in plain degrees — MKCoordinateRegion without the
/// MapKit dependency, so clustering stays testable from Core.
public struct MapRegion: Hashable, Sendable, Codable {
    public var centerLatitude: Double
    public var centerLongitude: Double
    public var latitudeDelta: Double
    public var longitudeDelta: Double

    public init(
        centerLatitude: Double,
        centerLongitude: Double,
        latitudeDelta: Double,
        longitudeDelta: Double
    ) {
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }

    // The names a saved map camera has always had on disk.
    private enum CodingKeys: String, CodingKey {
        case centerLatitude = "latitude"
        case centerLongitude = "longitude"
        case latitudeDelta, longitudeDelta
    }

    /// The zoom as a distance: the shorter of the two spans, in meters.
    /// A map asked to show `d` meters fits `d` along the view's short
    /// axis and shows more along the long one, so re-framing from the
    /// long span would zoom out by the aspect ratio every time.
    public var shortSpanMeters: Double {
        let lat = latitudeDelta * 111_000
        let lon = longitudeDelta * 111_000 * cos(centerLatitude * .pi / 180)
        return min(lat, lon)
    }

    /// The smallest region showing every corner of `box`, grown by
    /// `padding` (fraction of each span) so pins don't sit on the edge.
    /// The floor keeps a near-degenerate box from producing a window
    /// too small to be useful (~55 m).
    public static func fitting(_ box: PhotoMapping.BoundingBox, padding: Double = 0.15) -> MapRegion
    {
        let latSpan = max(box.maxLat - box.minLat, 0.0005) * (1 + 2 * padding)
        let lngSpan = max(box.maxLng - box.minLng, 0.0005) * (1 + 2 * padding)
        return MapRegion(
            centerLatitude: (box.minLat + box.maxLat) / 2,
            centerLongitude: (box.minLng + box.maxLng) / 2,
            latitudeDelta: min(latSpan, 180),
            longitudeDelta: min(lngSpan, 360)
        )
    }
}

public struct MapCluster: Identifiable, Hashable, Sendable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let photoIds: [String]
    public let boundingBox: PhotoMapping.BoundingBox

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    public var count: Int { photoIds.count }
    public var isSingle: Bool { photoIds.count == 1 }
    /// Every photo at (effectively) one coordinate: zooming can't
    /// separate them.
    public var isPile: Bool {
        !isSingle
            && boundingBox.maxLat - boundingBox.minLat < 1e-6
            && boundingBox.maxLng - boundingBox.minLng < 1e-6
    }
}

public enum ClusterTapAction: Hashable, Sendable {
    case zoom(MapRegion)
    /// A pile, or photos closer than the finest cell.
    case list
}

/// Cells are anchored to absolute coordinates, not to the viewport, so
/// panning doesn't reshuffle clusters; only zooming does. The area is
/// grown to whole cells for the same reason: a cell cut by the edge would
/// report a different count and centroid after every pan.
public enum MapClustering {
    /// How far past the viewport pins are always built, as a fraction
    /// of its span on each side, however dense the map is.
    public static let defaultMargin = 0.5

    /// Annotation views the map is asked to hold at once. The count
    /// grows with the square of the margin, so a dense map gets a
    /// narrower one. Measured on the simulator, a rebuild stalls the
    /// map for roughly 40 ms per hundred annotations.
    public static let annotationBudget = 200

    public static func clusters(
        pins: [PhotoMapPin],
        in region: MapRegion,
        columns: Int = 6,
        margin: Double = defaultMargin
    ) -> [MapCluster] {
        let cell = cellSize(for: region.longitudeDelta, columns: columns)
        let area = coverage(of: region, cell: cell, margin: margin)
        let visible = pins.filter { pin in
            let lat = pin.coordinate.latitude
            let lng = pin.coordinate.longitude
            return lat >= area.minLat && lat <= area.maxLat
                && lng >= area.minLng && lng <= area.maxLng
        }
        guard !visible.isEmpty else { return [] }

        struct Bucket {
            var ids: [String] = []
            var sumLat = 0.0
            var sumLng = 0.0
            var box: PhotoMapping.BoundingBox?
        }
        var buckets: [String: Bucket] = [:]
        for pin in visible {
            let lat = pin.coordinate.latitude
            let lng = pin.coordinate.longitude
            let key =
                "\(cell)/\(Int((lat / cell).rounded(.down)))/\(Int((lng / cell).rounded(.down)))"
            var bucket = buckets[key] ?? Bucket()
            bucket.ids.append(pin.photoId)
            bucket.sumLat += lat
            bucket.sumLng += lng
            bucket.box = PhotoMapping.BoundingBox(
                minLat: min(bucket.box?.minLat ?? lat, lat),
                maxLat: max(bucket.box?.maxLat ?? lat, lat),
                minLng: min(bucket.box?.minLng ?? lng, lng),
                maxLng: max(bucket.box?.maxLng ?? lng, lng)
            )
            buckets[key] = bucket
        }

        return buckets.keys.sorted().compactMap { key in
            guard let bucket = buckets[key], let box = bucket.box else { return nil }
            let n = Double(bucket.ids.count)
            return MapCluster(
                id: key,
                latitude: bucket.sumLat / n,
                longitude: bucket.sumLng / n,
                photoIds: bucket.ids,
                boundingBox: box
            )
        }
    }

    /// Always makes progress: if the cluster's photos would still share
    /// one cell after the zoom, they are listed instead.
    public static func tapAction(
        for cluster: MapCluster,
        pins: [PhotoMapPin],
        columns: Int = 6
    ) -> ClusterTapAction {
        if cluster.isPile { return .list }
        let target = MapRegion.fitting(cluster.boundingBox, padding: 0.3)
        let ids = Set(cluster.photoIds)
        let members = pins.filter { ids.contains($0.photoId) }
        let after = clusters(pins: members, in: target, columns: columns)
        return after.count > 1 ? .zoom(target) : .list
    }

    /// True once the zoom crosses into another cell size, or the viewport
    /// nears the built area's edge.
    public static func isStale(
        clustered: MapRegion,
        for region: MapRegion,
        columns: Int = 6,
        margin: Double = defaultMargin
    ) -> Bool {
        let cell = cellSize(for: region.longitudeDelta, columns: columns)
        if cell != cellSize(for: clustered.longitudeDelta, columns: columns) { return true }
        // Every rebuild re-lays all the annotations, which costs a
        // dropped frame or several however few of them changed. So
        // rebuild late: only when half a screen of built area is left.
        let reserve = min(margin / 2, 0.5)
        func outgrown(_ drift: Double, _ span: Double, _ builtSpan: Double) -> Bool {
            abs(drift) + span * (0.5 + reserve) > builtSpan * (0.5 + margin)
        }
        return outgrown(
            region.centerLatitude - clustered.centerLatitude,
            region.latitudeDelta, clustered.latitudeDelta)
            || outgrown(
                region.centerLongitude - clustered.centerLongitude,
                region.longitudeDelta, clustered.longitudeDelta)
    }

    private static func coverage(
        of region: MapRegion, cell: Double, margin: Double
    ) -> PhotoMapping.BoundingBox {
        let latSpan = region.latitudeDelta * (1 + 2 * margin)
        let lngSpan = region.longitudeDelta * (1 + 2 * margin)
        return PhotoMapping.BoundingBox(
            minLat: ((region.centerLatitude - latSpan / 2) / cell).rounded(.down) * cell,
            maxLat: ((region.centerLatitude + latSpan / 2) / cell).rounded(.up) * cell,
            minLng: ((region.centerLongitude - lngSpan / 2) / cell).rounded(.down) * cell,
            maxLng: ((region.centerLongitude + lngSpan / 2) / cell).rounded(.up) * cell
        )
    }

    /// Largest power of two (in degrees) that fits `columns` times into
    /// the span. Floored so a fully zoomed-in map doesn't produce
    /// sub-meter cells.
    static func cellSize(for longitudeDelta: Double, columns: Int) -> Double {
        let target = max(longitudeDelta, 1e-6) / Double(max(columns, 1))
        let exponent = (log2(target)).rounded(.down)
        return max(pow(2, exponent), 1e-5)
    }
}
