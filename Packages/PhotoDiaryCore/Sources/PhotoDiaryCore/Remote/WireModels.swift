import CoreLocation
import Foundation

// Wire shapes for the server's /api/v1 responses. Mirrors the SPA's
// PhotoModel/GalleryModel input types: everything the server may
// omit is optional here, and the mapping into the domain types below
// decides the fallbacks in one place.

/// Decodes to nil instead of throwing, so one element a newer or an
/// odd server sends in a shape the app can't read costs that element,
/// not the whole list.
struct Lenient<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: Decoder) throws {
        value = try? Wrapped(from: decoder)
    }
}

struct GalleryDTO: Decodable {
    let id: String
    let title: String?
    let description: String?
}

struct MetaDTO: Decodable {
    /// Photo root override. When set, display/thumbnail paths hang off
    /// it instead of the API host — same rule the SPA applies.
    let cdn: String?
}

struct PhotoDTO: Decodable {
    /// Every part is null for a photo without a capture date.
    struct Instant: Decodable {
        let year: Int?
        let month: Int?
        let day: Int?
        let hour: Int?
        let minute: Int?
        let second: Int?
    }
    struct Coordinates: Decodable {
        let latitude: Double?
        let longitude: Double?
        let altitude: Double?
    }
    struct Location: Decodable {
        let country: String?
        let coordinates: Coordinates?
    }
    struct Taken: Decodable {
        let author: String?
        let instant: Instant
        let location: Location?
    }
    struct Gear: Decodable {
        let make: String?
        let model: String?
    }
    struct Exposure: Decodable {
        let focalLength: Double?
        let focalLength35mmEquiv: Double?
        let aperture: Double?
        let exposureTime: Double?
        let iso: Int?
    }
    struct Geocoded: Decodable {
        let countryCode: String?
    }

    let id: String
    let title: String?
    let taken: Taken
    let camera: Gear?
    let lens: Gear?
    let exposure: Exposure?
    let geocoded: Geocoded?
    /// Display rendition max dimensions the server generated for this
    /// photo. The largest is the viewer's source, like the SPA.
    let renditions: [Int]?
}

extension GalleryDTO {
    func toDomain() -> Gallery {
        Gallery(
            id: id,
            title: title ?? id,
            description: description ?? ""
        )
    }
}

extension PhotoDTO {
    /// Same fallback the SPA's Content.tsx uses when a photo predates
    /// the renditions column.
    static let fallbackRendition = 1500

    /// nil for a photo without a capture date: the app's two surfaces
    /// are a calendar and a map of dated photos, and it has no place
    /// on either.
    func toDomain(galleryId: String, photoRoot: URL) -> Photo? {
        guard let year = taken.instant.year, let month = taken.instant.month,
            let day = taken.instant.day
        else { return nil }
        let coords: CLLocationCoordinate2D? = {
            guard let c = taken.location?.coordinates,
                let lat = c.latitude, let lng = c.longitude
            else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }()
        let displayDim = renditions?.max() ?? Self.fallbackRendition
        let displayURL = photoRoot.appending(path: "display/\(displayDim)/\(id)")
        return Photo(
            id: id,
            galleryId: galleryId,
            title: title ?? "",
            author: taken.author,
            timestamp: PhotoTimestamp(
                year: year,
                month: month,
                day: day,
                hour: taken.instant.hour ?? 0,
                minute: taken.instant.minute ?? 0,
                second: taken.instant.second ?? 0
            ),
            location: PhotoLocation(
                country: taken.location?.country ?? geocoded?.countryCode,
                coordinates: coords,
                altitude: taken.location?.coordinates?.altitude
            ),
            camera: PhotoCamera(
                make: camera?.make,
                model: camera?.model,
                lensMake: lens?.make,
                lensModel: lens?.model
            ),
            exposure: PhotoExposure(
                focalLength: exposure?.focalLength,
                focalLength35mmEquiv: exposure?.focalLength35mmEquiv,
                aperture: exposure?.aperture,
                exposureTime: exposure?.exposureTime,
                iso: exposure?.iso
            ),
            displayImageURL: displayURL,
            thumbnailURL: photoRoot.appending(path: "thumbnail/\(id)")
        )
    }
}
