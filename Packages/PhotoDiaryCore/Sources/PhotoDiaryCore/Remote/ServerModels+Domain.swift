import CoreLocation
import Foundation

// From the server's shapes (generated from its OpenAPI document) to the
// app's own. The one place that decides what a missing value means.

extension Components.Schemas.Gallery {
    func toDomain() -> Gallery {
        Gallery(id: id, title: title ?? id, description: description ?? "")
    }
}

extension Components.Schemas.Photo {
    /// Same fallback the SPA's Content.tsx uses when a photo predates
    /// the renditions column.
    static let fallbackRendition = 1500

    /// nil for a photo without a capture date: the app's surfaces are a
    /// calendar and a map of dated photos, and it has no place on
    /// either.
    func toDomain(galleryId: String, photoRoot: URL) -> Photo? {
        let instant = taken.instant
        guard let year = instant.year, let month = instant.month, let day = instant.day
        else { return nil }
        let place = taken.location?.coordinates
        let coords: CLLocationCoordinate2D? = {
            guard let lat = place?.latitude, let lng = place?.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }()
        let displayDim = renditions?.max() ?? Self.fallbackRendition
        return Photo(
            id: id,
            galleryId: galleryId,
            title: title ?? "",
            author: taken.author,
            timestamp: PhotoTimestamp(
                year: year,
                month: month,
                day: day,
                hour: instant.hour ?? 0,
                minute: instant.minute ?? 0,
                second: instant.second ?? 0
            ),
            location: PhotoLocation(
                country: taken.location?.country ?? geocoded?.countryCode,
                coordinates: coords,
                altitude: place?.altitude
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
            displayImageURL: photoRoot.appending(path: "display/\(displayDim)/\(id)"),
            thumbnailURL: photoRoot.appending(path: "thumbnail/\(id)")
        )
    }
}
