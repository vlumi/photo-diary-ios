import Foundation
import XCTest

@testable import PhotoDiaryCore

final class WireModelsTests: XCTestCase {
    private let root = URL(string: "https://photos.example.test/")!

    private let fullPhoto = """
        {
          "id": "1.jpg", "index": 0, "title": "Some title", "description": "",
          "taken": {
            "instant": {"timestamp": "2020-01-01 13:00:15", "year": 2020, "month": 1, "day": 1,
                        "hour": 13, "minute": 0, "second": 15},
            "author": "Author One",
            "location": {"country": "jp", "place": "",
                         "coordinates": {"latitude": 30, "longitude": 31, "altitude": null}}
          },
          "camera": {"make": "CMake", "model": "CModel", "serial": null},
          "lens": {"make": "LMake", "model": "LModel", "serial": null},
          "exposure": {"focalLength": 23, "focalLength35mmEquiv": 35, "aperture": 2.8,
                       "exposureTime": 0.01, "iso": 100},
          "dimensions": {"original": {"width": 3000, "height": 2000},
                         "thumbnail": {"width": 300, "height": 200}},
          "renditions": [800, 2400, 1500]
        }
        """

    private let sparsePhoto = """
        {
          "id": "empty.jpg", "index": 0,
          "taken": {"instant": {"year": 2019, "month": 1, "day": 1}, "author": null,
                    "location": {"country": null, "place": null, "coordinates": {}}},
          "camera": {}, "lens": {},
          "exposure": {"focalLength": null, "aperture": null, "exposureTime": null, "iso": null},
          "geocoded": {"countryCode": "fi", "stateCode": "FI-18", "city": "Helsinki"},
          "dimensions": {"original": {"width": 300, "height": 200},
                         "thumbnail": {"width": 300, "height": 200}}
        }
        """

    func testFullPhotoMapsEveryField() throws {
        let dto = try JSONDecoder().decode(PhotoDTO.self, from: Data(fullPhoto.utf8))
        let photo = dto.toDomain(galleryId: "g1", photoRoot: root)
        XCTAssertEqual(photo.id, "1.jpg")
        XCTAssertEqual(photo.galleryId, "g1")
        XCTAssertEqual(photo.title, "Some title")
        XCTAssertEqual(photo.author, "Author One")
        XCTAssertEqual(
            photo.timestamp,
            PhotoTimestamp(year: 2020, month: 1, day: 1, hour: 13, minute: 0, second: 15)
        )
        XCTAssertEqual(photo.location.country, "jp")
        XCTAssertEqual(photo.location.coordinates?.latitude, 30)
        XCTAssertEqual(photo.location.coordinates?.longitude, 31)
        XCTAssertEqual(photo.camera.displayName, "CMake CModel")
        XCTAssertEqual(photo.camera.lensModel, "LModel")
        XCTAssertEqual(photo.exposure.focalLength35mmEquiv, 35)
        XCTAssertEqual(photo.exposure.iso, 100)
        // Largest rendition wins, regardless of array order.
        XCTAssertEqual(
            photo.displayImageURL.absoluteString,
            "https://photos.example.test/display/2400/1.jpg"
        )
        XCTAssertEqual(
            photo.thumbnailURL.absoluteString,
            "https://photos.example.test/thumbnail/1.jpg"
        )
    }

    func testSparsePhotoFallsBackSensibly() throws {
        let dto = try JSONDecoder().decode(PhotoDTO.self, from: Data(sparsePhoto.utf8))
        let photo = dto.toDomain(galleryId: "g1", photoRoot: root)
        XCTAssertEqual(photo.title, "")
        XCTAssertNil(photo.author)
        XCTAssertEqual(photo.timestamp.hour, 0)
        XCTAssertNil(photo.location.coordinates, "empty coordinates object is not a location")
        XCTAssertEqual(
            photo.location.country, "fi",
            "geocoded country backs up a null operator country"
        )
        XCTAssertNil(photo.camera.displayName)
        XCTAssertEqual(
            photo.displayImageURL.absoluteString,
            "https://photos.example.test/display/1500/empty.jpg",
            "no renditions column → the SPA's 1500 fallback"
        )
    }

    func testGalleryTitleFallsBackToId() throws {
        let dto = try JSONDecoder().decode(
            GalleryDTO.self, from: Data(#"{"id":"g1","hideMap":false}"#.utf8))
        let gallery = dto.toDomain()
        XCTAssertEqual(gallery.title, "g1")
        XCTAssertNil(gallery.photoCount)
    }
}
