import CoreLocation
import Foundation

/// A map viewport in plain degrees — MKCoordinateRegion without the
/// MapKit dependency, so clustering stays testable from Core.
public struct MapRegion: Hashable, Sendable {
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

    /// The smallest region showing every corner of `box`, grown by
    /// `padding` (fraction of each span) so pins don't sit on the edge.
    /// A degenerate box (one point) gets a fixed ~1 km-ish window.
    public static func fitting(_ box: PhotoMapping.BoundingBox, padding: Double = 0.15) -> MapRegion
    {
        let latSpan = max(box.maxLat - box.minLat, 0.01) * (1 + 2 * padding)
        let lngSpan = max(box.maxLng - box.minLng, 0.01) * (1 + 2 * padding)
        return MapRegion(
            centerLatitude: (box.minLat + box.maxLat) / 2,
            centerLongitude: (box.minLng + box.maxLng) / 2,
            latitudeDelta: min(latSpan, 180),
            longitudeDelta: min(lngSpan, 360)
        )
    }
}

/// One rendered map annotation: either a single photo or a pile of
/// them sharing a grid cell at the current zoom.
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
    /// separate them, so the UI lists them instead.
    public var isPile: Bool {
        !isSingle
            && boundingBox.maxLat - boundingBox.minLat < 1e-6
            && boundingBox.maxLng - boundingBox.minLng < 1e-6
    }
}

/// Viewport culling + grid clustering. Thousands of pins become at
/// most a few dozen annotations: only pins inside the region (plus a
/// margin) are considered, and those are bucketed into square cells
/// whose size is a power of two in degrees chosen so about `columns`
/// cells span the viewport. Cells are anchored to absolute
/// coordinates, not to the viewport, so panning doesn't reshuffle
/// clusters — only zooming does.
public enum MapClustering {
    public static func clusters(
        pins: [PhotoMapPin],
        in region: MapRegion,
        columns: Int = 6,
        margin: Double = 0.25
    ) -> [MapCluster] {
        let latSpan = region.latitudeDelta * (1 + 2 * margin)
        let lngSpan = region.longitudeDelta * (1 + 2 * margin)
        let minLat = region.centerLatitude - latSpan / 2
        let maxLat = region.centerLatitude + latSpan / 2
        let minLng = region.centerLongitude - lngSpan / 2
        let maxLng = region.centerLongitude + lngSpan / 2

        let visible = pins.filter { pin in
            let lat = pin.coordinate.latitude
            let lng = pin.coordinate.longitude
            return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng
        }
        guard !visible.isEmpty else { return [] }

        let cell = cellSize(for: region.longitudeDelta, columns: columns)

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

    /// Largest power of two (in degrees) that fits `columns` times into
    /// the viewport's longitude span. Floored to a sane minimum so a
    /// fully zoomed-in map doesn't produce sub-metre cells.
    static func cellSize(for longitudeDelta: Double, columns: Int) -> Double {
        let target = max(longitudeDelta, 1e-6) / Double(max(columns, 1))
        let exponent = (log2(target)).rounded(.down)
        return max(pow(2, exponent), 1e-5)
    }
}
