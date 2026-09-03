import XCTest
@testable import PhotoDiaryCore

final class PhotoDiaryCoreTests: XCTestCase {
    func testScaffoldVersion() throws {
        XCTAssertEqual(PhotoDiaryCore.scaffoldVersion, "0.0.1")
    }
}
