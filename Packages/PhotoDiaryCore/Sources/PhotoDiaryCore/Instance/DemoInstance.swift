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

private struct DailyAnchor {
    let day: Int
    let lat: Double
    let lng: Double
    let place: String
}

private struct FamilyEntry {
    let id: String
    let year: Int
    let month: Int
    let day: Int
    let lat: Double
    let lng: Double
    let country: String
    let place: String
    let cameraMake: String
    let cameraModel: String
}

extension DemoInstance {
    fileprivate static func buildDailyPhotos(galleryId: String) -> [Photo] {
        dailyAnchors.map { anchor in dailyPhoto(from: anchor, galleryId: galleryId) }
    }

    fileprivate static func buildFamilyPhotos(galleryId: String) -> [Photo] {
        familyEntries.map { entry in familyPhoto(from: entry, galleryId: galleryId) }
    }

    private static func dailyPhoto(from anchor: DailyAnchor, galleryId: String) -> Photo {
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

    private static func familyPhoto(from entry: FamilyEntry, galleryId: String) -> Photo {
        let month = String(format: "%02d", entry.month)
        let day = String(format: "%02d", entry.day)
        return Photo(
            id: entry.id,
            galleryId: galleryId,
            title: "\(entry.place) — \(entry.year)-\(month)-\(day)",
            author: "Ville Misaki",
            timestamp: PhotoTimestamp(
                year: entry.year, month: entry.month, day: entry.day,
                hour: 12, minute: (entry.day * 7) % 60, second: 0
            ),
            location: PhotoLocation(
                country: entry.country,
                coordinates: CLLocationCoordinate2D(latitude: entry.lat, longitude: entry.lng)
            ),
            camera: PhotoCamera(make: entry.cameraMake, model: entry.cameraModel),
            exposure: PhotoExposure(
                focalLength: 35,
                focalLength35mmEquiv: 35,
                aperture: 4.0,
                exposureTime: 1.0 / 125.0,
                iso: 400
            ),
            displayImageURL: demoImageURL(kind: "display", id: entry.id),
            thumbnailURL: demoImageURL(kind: "thumb", id: entry.id)
        )
    }

    // A daily project across ~three weeks. Same camera + lens
    // (mirroring an operator who shoots on one body), rotating between
    // neighbourhoods in Tokyo.
    private static let dailyAnchors: [DailyAnchor] = [
        .init(day: 1, lat: 35.6595, lng: 139.7005, place: "Shibuya"),
        .init(day: 2, lat: 35.6580, lng: 139.7016, place: "Shibuya"),
        .init(day: 3, lat: 35.7100, lng: 139.7967, place: "Ueno"),
        .init(day: 4, lat: 35.6762, lng: 139.7649, place: "Chiyoda"),
        .init(day: 5, lat: 35.6586, lng: 139.7454, place: "Roppongi"),
        .init(day: 6, lat: 35.6650, lng: 139.7708, place: "Ginza"),
        .init(day: 7, lat: 35.6812, lng: 139.7671, place: "Marunouchi"),
        .init(day: 8, lat: 35.7148, lng: 139.7967, place: "Ueno"),
        .init(day: 9, lat: 35.6284, lng: 139.7387, place: "Shinagawa"),
        .init(day: 10, lat: 35.6329, lng: 139.8804, place: "Kasai"),
        .init(day: 11, lat: 35.6975, lng: 139.7737, place: "Kanda"),
        .init(day: 12, lat: 35.7295, lng: 139.7109, place: "Ikebukuro"),
        .init(day: 13, lat: 35.6693, lng: 139.7016, place: "Meguro"),
        .init(day: 14, lat: 35.7148, lng: 139.7735, place: "Yanaka"),
        .init(day: 15, lat: 35.6520, lng: 139.8395, place: "Kiba"),
        .init(day: 16, lat: 35.6721, lng: 139.7635, place: "Ginza"),
        .init(day: 17, lat: 35.6935, lng: 139.7038, place: "Shinjuku"),
        .init(day: 18, lat: 35.6605, lng: 139.7290, place: "Ebisu"),
        .init(day: 19, lat: 35.6812, lng: 139.7671, place: "Marunouchi"),
        .init(day: 20, lat: 35.7091, lng: 139.8104, place: "Sumida"),
    ]

    // A family gallery: several trips, mixed bodies, less regular
    // cadence. Locations across a few countries so the map isn't just
    // Tokyo.
    private static let familyEntries: [FamilyEntry] = [
        .init(
            id: "family-2022-04-11", year: 2022, month: 4, day: 11,
            lat: 60.1699, lng: 24.9384, country: "FI", place: "Helsinki",
            cameraMake: "Apple", cameraModel: "iPhone 14 Pro"
        ),
        .init(
            id: "family-2022-04-12", year: 2022, month: 4, day: 12,
            lat: 60.1717, lng: 24.9414, country: "FI", place: "Helsinki",
            cameraMake: "Apple", cameraModel: "iPhone 14 Pro"
        ),
        .init(
            id: "family-2022-08-03", year: 2022, month: 8, day: 3,
            lat: 48.8566, lng: 2.3522, country: "FR", place: "Paris",
            cameraMake: "FUJIFILM", cameraModel: "X-T4"
        ),
        .init(
            id: "family-2022-08-04", year: 2022, month: 8, day: 4,
            lat: 48.8606, lng: 2.3376, country: "FR", place: "Paris",
            cameraMake: "FUJIFILM", cameraModel: "X-T4"
        ),
        .init(
            id: "family-2022-08-05", year: 2022, month: 8, day: 5,
            lat: 48.8738, lng: 2.2950, country: "FR", place: "Paris",
            cameraMake: "FUJIFILM", cameraModel: "X-T4"
        ),
        .init(
            id: "family-2023-01-02", year: 2023, month: 1, day: 2,
            lat: 35.6762, lng: 139.6503, country: "JP", place: "Tokyo",
            cameraMake: "Apple", cameraModel: "iPhone 14 Pro"
        ),
        .init(
            id: "family-2023-01-04", year: 2023, month: 1, day: 4,
            lat: 34.6937, lng: 135.5023, country: "JP", place: "Osaka",
            cameraMake: "FUJIFILM", cameraModel: "X-T4"
        ),
        .init(
            id: "family-2023-01-05", year: 2023, month: 1, day: 5,
            lat: 34.9855, lng: 135.7585, country: "JP", place: "Uji",
            cameraMake: "FUJIFILM", cameraModel: "X-T4"
        ),
        .init(
            id: "family-2023-06-18", year: 2023, month: 6, day: 18,
            lat: 60.4518, lng: 22.2666, country: "FI", place: "Turku",
            cameraMake: "Apple", cameraModel: "iPhone 14 Pro"
        ),
        .init(
            id: "family-2023-12-24", year: 2023, month: 12, day: 24,
            lat: 60.1699, lng: 24.9384, country: "FI", place: "Helsinki",
            cameraMake: "Apple", cameraModel: "iPhone 14 Pro"
        ),
    ]

    /// Custom scheme so the eventual image loader knows to route these
    /// through the bundled-resource path rather than URLSession. Kept
    /// distinct from the app's own `photodiary://` scheme (that one is
    /// for SSO pairing).
    private static func demoImageURL(kind: String, id: String) -> URL {
        URL(string: "photodiary-demo://\(kind)/\(id).jpg")!
    }
}
