import XCTest
@testable import PhotoDiaryCore

final class DemoInstanceTests: XCTestCase {
    func testExposesTwoGalleries() async throws {
        let instance = DemoInstance()
        let galleries = try await instance.listGalleries()
        XCTAssertEqual(galleries.map(\.id).sorted(), ["daily", "family"])
    }

    func testPhotoCountMatchesTheListedPhotoCountField() async throws {
        let instance = DemoInstance()
        for gallery in try await instance.listGalleries() {
            let photos = try await instance.listPhotos(inGallery: gallery.id)
            XCTAssertEqual(
                photos.count, gallery.photoCount,
                "photoCount on Gallery \(gallery.id) diverges from listPhotos length"
            )
        }
    }

    func testEveryPhotoInDailyHasCoordinates() async throws {
        // Daily is intentionally fully geotagged so the map surface
        // has something to render out of the box. Family is more
        // realistic — mixed coordinate coverage — but daily should
        // be plottable in full.
        let instance = DemoInstance()
        let daily = try await instance.listPhotos(inGallery: "daily")
        for photo in daily {
            XCTAssertNotNil(photo.location.coordinates, "daily photo \(photo.id) has no coords")
        }
    }

    func testGetPhotoReturnsMatchingId() async throws {
        let instance = DemoInstance()
        let daily = try await instance.listPhotos(inGallery: "daily")
        let first = daily.first!
        let fetched = try await instance.getPhoto(id: first.id, inGallery: "daily")
        XCTAssertEqual(fetched.id, first.id)
    }

    func testGetPhotoUnknownIdThrows() async throws {
        let instance = DemoInstance()
        do {
            _ = try await instance.getPhoto(id: "nonexistent", inGallery: "daily")
            XCTFail("expected throw")
        } catch InstanceError.photoNotFound {
            // Expected.
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testListPhotosUnknownGalleryThrows() async throws {
        let instance = DemoInstance()
        do {
            _ = try await instance.listPhotos(inGallery: "nonexistent")
            XCTFail("expected throw")
        } catch InstanceError.galleryNotFound {
            // Expected.
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
