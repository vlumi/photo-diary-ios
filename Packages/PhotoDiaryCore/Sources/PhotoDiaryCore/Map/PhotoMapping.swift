import CoreLocation
import Foundation

/// A photo pinned to a coordinate. Value type — the map surface
/// materializes an array of these from an [Photo] filter step and
/// hands them to SwiftUI without touching the raw Photo again.
public struct PhotoMapPin: Identifiable, Hashable, Sendable {
    public let photoId: String
    public let coordinate: CLLocationCoordinate2D

    public var id: String { photoId }

    public init(photoId: String, coordinate: CLLocationCoordinate2D) {
        self.photoId = photoId
        self.coordinate = coordinate
    }

    // CLLocationCoordinate2D is not Hashable/Equatable; derive both
    // from (id, lat, lng) so pins survive SwiftUI diffing.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(photoId)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }

    public static func == (lhs: PhotoMapPin, rhs: PhotoMapPin) -> Bool {
        lhs.photoId == rhs.photoId
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

public enum PhotoMapping {
    /// Every photo that has a GPS coordinate, in the same order as the
    /// input. Photos without coordinates are dropped silently — the
    /// map surface renders a 'no map-plottable photos' state elsewhere
    /// when the result is empty.
    public static func pins(from photos: [Photo]) -> [PhotoMapPin] {
        photos.compactMap { photo in
            guard let coord = photo.location.coordinates else { return nil }
            return PhotoMapPin(photoId: photo.id, coordinate: coord)
        }
    }

    /// Bounding box that fits every pin, or nil if there are none.
    /// Used to fit the map viewport on first load. The caller adds
    /// padding — the pad amount depends on the map's rendered height.
    public static func boundingBox(of pins: [PhotoMapPin]) -> BoundingBox? {
        guard let first = pins.first else { return nil }
        var minLat = first.coordinate.latitude
        var maxLat = first.coordinate.latitude
        var minLng = first.coordinate.longitude
        var maxLng = first.coordinate.longitude
        for pin in pins.dropFirst() {
            let lat = pin.coordinate.latitude
            let lng = pin.coordinate.longitude
            if lat < minLat { minLat = lat }
            if lat > maxLat { maxLat = lat }
            if lng < minLng { minLng = lng }
            if lng > maxLng { maxLng = lng }
        }
        return BoundingBox(minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng)
    }

    public struct BoundingBox: Hashable, Sendable {
        public let minLat: Double
        public let maxLat: Double
        public let minLng: Double
        public let maxLng: Double
    }
}
