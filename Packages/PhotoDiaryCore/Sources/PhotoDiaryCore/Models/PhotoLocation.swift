import CoreLocation

/// Where a photo was taken. `country` is an ISO 3166-1 alpha-2 code
/// (matching the server's `taken.location.country` shape). `coordinates`
/// is optional — many photos have no GPS. When both are absent the
/// photo isn't map-plottable.
public struct PhotoLocation: Hashable, Sendable {
    public let country: String?
    public let coordinates: CLLocationCoordinate2D?
    public let altitude: Double?

    public init(country: String? = nil, coordinates: CLLocationCoordinate2D? = nil, altitude: Double? = nil) {
        self.country = country
        self.coordinates = coordinates
        self.altitude = altitude
    }
}

// CLLocationCoordinate2D isn't Hashable/Sendable out of the box; give
// PhotoLocation an explicit conformance that treats the coord as its
// lat/lng pair.
extension PhotoLocation {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(country)
        hasher.combine(coordinates?.latitude)
        hasher.combine(coordinates?.longitude)
        hasher.combine(altitude)
    }

    public static func == (lhs: PhotoLocation, rhs: PhotoLocation) -> Bool {
        lhs.country == rhs.country
            && lhs.coordinates?.latitude == rhs.coordinates?.latitude
            && lhs.coordinates?.longitude == rhs.coordinates?.longitude
            && lhs.altitude == rhs.altitude
    }
}
