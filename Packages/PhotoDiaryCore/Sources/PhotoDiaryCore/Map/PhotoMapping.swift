import CoreLocation
import Foundation

public struct PhotoMapPin: Identifiable, Hashable, Sendable {
    public let photoId: String
    public let coordinate: CLLocationCoordinate2D

    public var id: String { photoId }

    public init(photoId: String, coordinate: CLLocationCoordinate2D) {
        self.photoId = photoId
        self.coordinate = coordinate
    }

    // CLLocationCoordinate2D isn't Hashable.
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
    public static func pins(from photos: [Photo]) -> [PhotoMapPin] {
        photos.compactMap { photo in
            guard let coord = photo.location.coordinates else { return nil }
            return PhotoMapPin(photoId: photo.id, coordinate: coord)
        }
    }

    /// Where the map opens.
    public static func latestGeotagged(in photos: [Photo]) -> Photo? {
        photos
            .filter { $0.location.coordinates != nil }
            .max { $0.timestamp < $1.timestamp }
    }

    public struct BoundingBox: Hashable, Sendable {
        public let minLat: Double
        public let maxLat: Double
        public let minLng: Double
        public let maxLng: Double
    }
}
