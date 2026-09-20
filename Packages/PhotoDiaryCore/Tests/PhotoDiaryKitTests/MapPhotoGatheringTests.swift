import Foundation
import PhotoDiaryCore
import XCTest

@testable import PhotoDiaryKit

final class MapPhotoGatheringTests: XCTestCase {
    /// Two galleries; `gone` is listed but answers 404 when asked for
    /// its photos, as a gallery does that vanished in between.
    private struct FakeInstance: Instance {
        let id = "fake"
        let displayName = "Fake"
        let isDemo = false

        func listGalleries() async throws -> [Gallery] {
            [Gallery(id: "here", title: "Here"), Gallery(id: "gone", title: "Gone")]
        }

        func listPhotos(inGallery galleryId: String) async throws -> [Photo] {
            guard galleryId == "here" else { throw InstanceError.galleryNotFound(galleryId) }
            return [
                Photo(
                    id: "p1", galleryId: galleryId,
                    timestamp: PhotoTimestamp(
                        year: 2024, month: 6, day: 1, hour: 12, minute: 0, second: 0),
                    displayImageURL: URL(string: "https://example.test/display/p1")!,
                    thumbnailURL: URL(string: "https://example.test/thumbnail/p1")!)
            ]
        }

        func getPhoto(id: String, inGallery galleryId: String) async throws -> Photo {
            throw InstanceError.photoNotFound(id)
        }

        func cachedGalleries() async -> [Gallery]? { nil }
        func cachedPhotos(inGallery galleryId: String) async -> [Photo]? { nil }
    }

    func testAnAllGalleriesScopeSkipsAGalleryThatWentAway() async throws {
        let photos = try await MapPhotoGathering.photos(
            of: Scope(instanceId: "fake"), from: FakeInstance(), cached: false)
        XCTAssertEqual(photos?.map(\.id), ["p1"])
    }

    func testLosingTheGalleryTheScopeIsAboutStillFails() async {
        do {
            _ = try await MapPhotoGathering.photos(
                of: Scope(instanceId: "fake", galleryId: "gone"), from: FakeInstance(),
                cached: false)
            XCTFail("the scope's own gallery is gone; that has to surface")
        } catch InstanceError.galleryNotFound(let id) {
            XCTAssertEqual(id, "gone")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
