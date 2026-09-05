import XCTest
@testable import PhotoDiaryCore

final class PhotoTimestampTests: XCTestCase {
    func testOrderingWithinSameDay() {
        let earlier = PhotoTimestamp(year: 2024, month: 6, day: 15, hour: 10, minute: 30, second: 0)
        let later = PhotoTimestamp(year: 2024, month: 6, day: 15, hour: 14, minute: 5, second: 0)
        XCTAssertLessThan(earlier, later)
    }

    func testOrderingAcrossYears() {
        let earlier = PhotoTimestamp(year: 2023, month: 12, day: 31, hour: 23, minute: 59, second: 59)
        let later = PhotoTimestamp(year: 2024, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        XCTAssertLessThan(earlier, later)
    }

    func testAsLocalDateRoundtripsDigits() {
        // The digits above are the source of truth; asLocalDate is a
        // convenience whose interpretation depends on Calendar.current.
        let ts = PhotoTimestamp(year: 2024, month: 6, day: 15, hour: 10, minute: 30, second: 45)
        guard let d = ts.asLocalDate else {
            XCTFail("asLocalDate returned nil for a well-formed timestamp")
            return
        }
        let recovered = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: d
        )
        XCTAssertEqual(recovered.year, 2024)
        XCTAssertEqual(recovered.month, 6)
        XCTAssertEqual(recovered.day, 15)
        XCTAssertEqual(recovered.hour, 10)
        XCTAssertEqual(recovered.minute, 30)
        XCTAssertEqual(recovered.second, 45)
    }
}

final class PhotoCameraTests: XCTestCase {
    func testDisplayNameJoinsMakeAndModel() {
        let cam = PhotoCamera(make: "FUJIFILM", model: "X-T2")
        XCTAssertEqual(cam.displayName, "FUJIFILM X-T2")
    }

    func testDisplayNameHandlesMissingHalf() {
        XCTAssertEqual(PhotoCamera(make: "FUJIFILM").displayName, "FUJIFILM")
        XCTAssertEqual(PhotoCamera(model: "X-T2").displayName, "X-T2")
    }

    func testDisplayNameIsNilWhenBothMissing() {
        XCTAssertNil(PhotoCamera().displayName)
    }

    func testDisplayNameIgnoresEmptyStrings() {
        XCTAssertNil(PhotoCamera(make: "", model: "").displayName)
    }
}
