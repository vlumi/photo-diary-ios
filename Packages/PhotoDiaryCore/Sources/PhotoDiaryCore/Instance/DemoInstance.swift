import CoreLocation
import Foundation

/// Fixture-backed Instance. Ships in v1 as the App Store review path,
/// the screenshot source, and the offline dev fallback. Data lives in
/// this file — small enough that a separate resource JSON would be
/// more indirection than help. Photo bytes are resolved by
/// `photodiary-demo://<id>.jpg` URLs; the image loader hasn't been
/// written yet, so the photo viewer will show a placeholder until
/// that's wired up in a follow-up commit.
public struct DemoInstance: Instance {
    public let id = "demo"
    public let displayName = "Demo"
    public let isDemo = true

    private let galleries: [Gallery]
    private let photosByGallery: [String: [Photo]]

    public init() {
        let dailyId = "daily"
        let familyId = "family"

        let dailyPhotos = DemoInstance.buildDailyPhotos(galleryId: dailyId)
        let familyPhotos = DemoInstance.buildFamilyPhotos(galleryId: familyId)

        self.galleries = [
            Gallery(
                id: dailyId,
                title: "Daily",
                description: "A daily photo project, one shot per day.",
                photoCount: dailyPhotos.count
            ),
            Gallery(
                id: familyId,
                title: "Family",
                description: "Trips, moments, gatherings.",
                photoCount: familyPhotos.count
            ),
        ]
        self.photosByGallery = [
            dailyId: dailyPhotos,
            familyId: familyPhotos,
        ]
    }

    public func listGalleries() async throws -> [Gallery] {
        galleries
    }

    public func listPhotos(inGallery galleryId: String) async throws -> [Photo] {
        guard let photos = photosByGallery[galleryId] else {
            throw InstanceError.galleryNotFound(galleryId)
        }
        return photos
    }

    public func getPhoto(id: String, inGallery galleryId: String) async throws -> Photo {
        guard let photos = photosByGallery[galleryId] else {
            throw InstanceError.galleryNotFound(galleryId)
        }
        guard let match = photos.first(where: { $0.id == id }) else {
            throw InstanceError.photoNotFound(id)
        }
        return match
    }
}

// MARK: - Fixture data
//
// Two galleries with plausible-looking EXIF + GPS + timestamps. GPS
// coordinates point at real cities so the map surface has something
// meaningful to cluster; EXIF fields reference real bodies + lenses so
// the metadata panel reads correctly. Image bytes are TBD — see the
// comment on the URL scheme above.

extension DemoInstance {
    fileprivate static func buildDailyPhotos(galleryId: String) -> [Photo] {
        // A daily project across ~three weeks. Same camera + lens
        // (mirroring an operator who shoots on one body), rotating
        // between neighbourhoods in Tokyo.
        let anchors: [(day: Int, lat: Double, lng: Double, place: String)] = [
            (1, 35.6595, 139.7005, "Shibuya"),
            (2, 35.6580, 139.7016, "Shibuya"),
            (3, 35.7100, 139.7967, "Ueno"),
            (4, 35.6762, 139.7649, "Chiyoda"),
            (5, 35.6586, 139.7454, "Roppongi"),
            (6, 35.6650, 139.7708, "Ginza"),
            (7, 35.6812, 139.7671, "Marunouchi"),
            (8, 35.7148, 139.7967, "Ueno"),
            (9, 35.6284, 139.7387, "Shinagawa"),
            (10, 35.6329, 139.8804, "Kasai"),
            (11, 35.6975, 139.7737, "Kanda"),
            (12, 35.7295, 139.7109, "Ikebukuro"),
            (13, 35.6693, 139.7016, "Meguro"),
            (14, 35.7148, 139.7735, "Yanaka"),
            (15, 35.6520, 139.8395, "Kiba"),
            (16, 35.6721, 139.7635, "Ginza"),
            (17, 35.6935, 139.7038, "Shinjuku"),
            (18, 35.6605, 139.7290, "Ebisu"),
            (19, 35.6812, 139.7671, "Marunouchi"),
            (20, 35.7091, 139.8104, "Sumida"),
        ]
        return anchors.map { anchor in
            let id = String(format: "daily-2024-06-%02d", anchor.day)
            return Photo(
                id: id,
                galleryId: galleryId,
                title: "Day \(anchor.day) — \(anchor.place)",
                author: "Ville Misaki",
                timestamp: PhotoTimestamp(
                    year: 2024,
                    month: 6,
                    day: anchor.day,
                    hour: 9 + (anchor.day % 8),
                    minute: (anchor.day * 13) % 60,
                    second: 0
                ),
                location: PhotoLocation(
                    country: "JP",
                    coordinates: CLLocationCoordinate2D(latitude: anchor.lat, longitude: anchor.lng)
                ),
                camera: PhotoCamera(make: "FUJIFILM", model: "X100F"),
                exposure: PhotoExposure(
                    focalLength: 23,
                    focalLength35mmEquiv: 35,
                    aperture: 5.6,
                    exposureTime: 1.0 / 250.0,
                    iso: 200
                ),
                displayImageURL: demoImageURL(kind: "display", id: id),
                thumbnailURL: demoImageURL(kind: "thumb", id: id)
            )
        }
    }

    fileprivate static func buildFamilyPhotos(galleryId: String) -> [Photo] {
        // A family gallery: several trips, mixed bodies, less regular
        // cadence. Locations across a few countries so the map isn't
        // just Tokyo.
        let entries: [(id: String, y: Int, m: Int, d: Int, lat: Double, lng: Double, country: String, place: String, camera: (String, String))] = [
            ("family-2022-04-11", 2022, 4, 11, 60.1699, 24.9384, "FI", "Helsinki", ("Apple", "iPhone 14 Pro")),
            ("family-2022-04-12", 2022, 4, 12, 60.1717, 24.9414, "FI", "Helsinki", ("Apple", "iPhone 14 Pro")),
            ("family-2022-08-03", 2022, 8, 3, 48.8566, 2.3522, "FR", "Paris", ("FUJIFILM", "X-T4")),
            ("family-2022-08-04", 2022, 8, 4, 48.8606, 2.3376, "FR", "Paris", ("FUJIFILM", "X-T4")),
            ("family-2022-08-05", 2022, 8, 5, 48.8738, 2.2950, "FR", "Paris", ("FUJIFILM", "X-T4")),
            ("family-2023-01-02", 2023, 1, 2, 35.6762, 139.6503, "JP", "Tokyo", ("Apple", "iPhone 14 Pro")),
            ("family-2023-01-04", 2023, 1, 4, 34.6937, 135.5023, "JP", "Osaka", ("FUJIFILM", "X-T4")),
            ("family-2023-01-05", 2023, 1, 5, 34.9855, 135.7585, "JP", "Uji", ("FUJIFILM", "X-T4")),
            ("family-2023-06-18", 2023, 6, 18, 60.4518, 22.2666, "FI", "Turku", ("Apple", "iPhone 14 Pro")),
            ("family-2023-12-24", 2023, 12, 24, 60.1699, 24.9384, "FI", "Helsinki", ("Apple", "iPhone 14 Pro")),
        ]
        return entries.map { e in
            Photo(
                id: e.id,
                galleryId: galleryId,
                title: "\(e.place) — \(e.y)-\(String(format: "%02d", e.m))-\(String(format: "%02d", e.d))",
                author: "Ville Misaki",
                timestamp: PhotoTimestamp(
                    year: e.y, month: e.m, day: e.d,
                    hour: 12, minute: (e.d * 7) % 60, second: 0
                ),
                location: PhotoLocation(
                    country: e.country,
                    coordinates: CLLocationCoordinate2D(latitude: e.lat, longitude: e.lng)
                ),
                camera: PhotoCamera(make: e.camera.0, model: e.camera.1),
                exposure: PhotoExposure(
                    focalLength: 35,
                    focalLength35mmEquiv: 35,
                    aperture: 4.0,
                    exposureTime: 1.0 / 125.0,
                    iso: 400
                ),
                displayImageURL: demoImageURL(kind: "display", id: e.id),
                thumbnailURL: demoImageURL(kind: "thumb", id: e.id)
            )
        }
    }

    /// Custom scheme so the eventual image loader knows to route these
    /// through the bundled-resource path rather than URLSession. Kept
    /// distinct from the app's own `photodiary://` scheme (that one is
    /// for SSO pairing).
    private static func demoImageURL(kind: String, id: String) -> URL {
        URL(string: "photodiary-demo://\(kind)/\(id).jpg")!
    }
}
