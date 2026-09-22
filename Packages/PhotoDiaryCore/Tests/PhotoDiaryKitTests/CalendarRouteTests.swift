import Foundation
import PhotoDiaryCore
import XCTest

@testable import PhotoDiaryKit

final class CalendarRouteTests: XCTestCase {
    private let photo = Photo(
        id: "p", galleryId: "daily",
        timestamp: PhotoTimestamp(year: 2024, month: 6, day: 3, hour: 9, minute: 0, second: 0),
        displayImageURL: URL(string: "https://example.test/display/p")!,
        thumbnailURL: URL(string: "https://example.test/thumbnail/p")!)

    func testThePathToAPhotoIsTheOneAUserWouldTapDown() {
        XCTAssertEqual(
            CalendarRoute.path(to: photo, inGalleryScope: false),
            [
                .years(galleryId: "daily"),
                .months(galleryId: "daily", year: 2024),
                .grid(galleryId: "daily", year: 2024, month: 6),
            ])
    }

    func testInAGalleryScopeTheYearListIsTheRootSoThePathStartsBelowIt() {
        XCTAssertEqual(
            CalendarRoute.path(to: photo, inGalleryScope: true),
            [
                .months(galleryId: "daily", year: 2024),
                .grid(galleryId: "daily", year: 2024, month: 6),
            ])
    }
}
