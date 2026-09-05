import XCTest
@testable import PhotoDiaryCore

final class PhotoCalendarTests: XCTestCase {
    func testYearsAreDistinctAndAscending() {
        let photos = [
            fixture(year: 2024, month: 3, day: 1),
            fixture(year: 2022, month: 5, day: 10),
            fixture(year: 2024, month: 12, day: 31),
            fixture(year: 2023, month: 1, day: 1),
        ]
        XCTAssertEqual(PhotoCalendar.years(in: photos), [2022, 2023, 2024])
    }

    func testMonthsAreScopedToYear() {
        let photos = [
            fixture(year: 2024, month: 3, day: 1),
            fixture(year: 2024, month: 6, day: 15),
            fixture(year: 2023, month: 3, day: 5),
        ]
        XCTAssertEqual(PhotoCalendar.months(in: 2024, of: photos), [3, 6])
        XCTAssertEqual(PhotoCalendar.months(in: 2023, of: photos), [3])
        XCTAssertEqual(PhotoCalendar.months(in: 1999, of: photos), [])
    }

    func testPhotosInYearSortAscending() {
        let a = fixture(year: 2024, month: 6, day: 3, hour: 12)
        let b = fixture(year: 2024, month: 6, day: 3, hour: 9)
        let c = fixture(year: 2024, month: 6, day: 1, hour: 15)
        let d = fixture(year: 2023, month: 1, day: 1)
        XCTAssertEqual(
            PhotoCalendar.photos(in: 2024, of: [a, b, c, d]).map(\.id),
            [c.id, b.id, a.id]
        )
    }

    func testGroupByDaySections() {
        let d3a = fixture(year: 2024, month: 6, day: 3, hour: 9)
        let d3b = fixture(year: 2024, month: 6, day: 3, hour: 15)
        let d1 = fixture(year: 2024, month: 6, day: 1, hour: 12)
        let d5 = fixture(year: 2024, month: 6, day: 5, hour: 8)
        let sections = PhotoCalendar.groupByDay([d3a, d3b, d1, d5])
        XCTAssertEqual(sections.map(\.day), [1, 3, 5])
        XCTAssertEqual(sections[1].photos.map(\.id), [d3a.id, d3b.id])
    }

    // MARK: - Fixture helper

    private func fixture(
        year: Int, month: Int, day: Int, hour: Int = 12
    ) -> Photo {
        Photo(
            id: "p-\(year)-\(month)-\(day)-\(hour)",
            galleryId: "g",
            timestamp: PhotoTimestamp(
                year: year, month: month, day: day, hour: hour, minute: 0, second: 0
            ),
            displayImageURL: URL(string: "photodiary-demo://display/x.jpg")!,
            thumbnailURL: URL(string: "photodiary-demo://thumb/x.jpg")!
        )
    }
}
