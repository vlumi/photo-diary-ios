import CoreLocation
import XCTest

@testable import PhotoDiaryCore

final class PhotoMappingTests: XCTestCase {
    func testPinsDropsPhotosWithoutCoordinates() {
        let a = fixture(id: "a", lat: 35.0, lng: 139.0)
        let b = fixture(id: "b", lat: nil, lng: nil)
        let c = fixture(id: "c", lat: 60.0, lng: 24.0)
        let pins = PhotoMapping.pins(from: [a, b, c])
        XCTAssertEqual(pins.map(\.photoId), ["a", "c"])
    }

    func testPinsPreservesInputOrder() {
        let pins = PhotoMapping.pins(from: [
            fixture(id: "third", lat: 3, lng: 3),
            fixture(id: "first", lat: 1, lng: 1),
            fixture(id: "second", lat: 2, lng: 2),
        ])
        XCTAssertEqual(pins.map(\.photoId), ["third", "first", "second"])
    }

    func testBoundingBoxSpansExtremes() {
        let pins = [
            PhotoMapPin(photoId: "a", coordinate: .init(latitude: 60, longitude: 24)),
            PhotoMapPin(photoId: "b", coordinate: .init(latitude: 35, longitude: 139)),
            PhotoMapPin(photoId: "c", coordinate: .init(latitude: 48, longitude: -3)),
        ]
        let box = PhotoMapping.boundingBox(of: pins)
        XCTAssertEqual(
            box,
            PhotoMapping.BoundingBox(
                minLat: 35, maxLat: 60, minLng: -3, maxLng: 139
            ))
    }

    func testBoundingBoxIsNilForEmpty() {
        XCTAssertNil(PhotoMapping.boundingBox(of: []))
    }

    // MARK: - Fixture

    private func fixture(id: String, lat: Double?, lng: Double?) -> Photo {
        let coords: CLLocationCoordinate2D? = {
            guard let lat, let lng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }()
        return Photo(
            id: id,
            galleryId: "g",
            timestamp: PhotoTimestamp(
                year: 2024, month: 1, day: 1, hour: 0, minute: 0, second: 0
            ),
            location: PhotoLocation(coordinates: coords),
            displayImageURL: URL(string: "photodiary-demo://display/\(id).jpg")!,
            thumbnailURL: URL(string: "photodiary-demo://thumb/\(id).jpg")!
        )
    }
}
