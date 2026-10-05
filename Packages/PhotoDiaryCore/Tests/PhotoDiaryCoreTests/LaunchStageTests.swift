import Testing

@testable import PhotoDiaryCore

struct LaunchStageTests {
    /// A staged launch with these arguments after the stage flag.
    private func stage(_ arguments: String...) throws -> LaunchStage {
        try #require(LaunchStage(arguments: ["app", "-photodiary-stage"] + arguments))
    }

    @Test func anOrdinaryLaunchIsNotStaged() {
        #expect(LaunchStage(arguments: ["app", "-photodiary-tab", "map"]) == nil)
    }

    @Test func aBareStageChangesNothing() throws {
        let bare = try stage()
        #expect(bare.opening == .unchanged)
        #expect(bare.tab == nil && bare.camera == nil && bare.pins.isEmpty)
    }

    @Test func aHostOpensItsOriginAndTheDemoKeepsItsId() throws {
        let remote = try stage(
            "-photodiary-scope", "photos.example", "-photodiary-gallery", "daily")
        #expect(
            remote.opening
                == .scope(Scope(instanceId: "https://photos.example", galleryId: "daily")))
        #expect(try stage("-photodiary-scope", "demo").opening == .scope(Scope(instanceId: "demo")))
        #expect(try stage("-photodiary-scope", "front").opening == .frontPage)
    }

    @Test func theCameraTakesOneSpanOrTwo() throws {
        let square = try stage("-photodiary-camera", "35.68, 139.76, 0.2")
        #expect(
            square.camera
                == .init(
                    latitude: 35.68, longitude: 139.76, latitudeDelta: 0.2, longitudeDelta: 0.2))
        let wide = try stage("-photodiary-camera", "35.68,139.76,0.2,0.4")
        #expect(wide.camera?.longitudeDelta == 0.4)
        #expect(try stage("-photodiary-camera", "x").camera == nil)
    }

    @Test func theCalendarStopsAtTheDepthGiven() throws {
        func stop(_ value: String) throws -> LaunchStage.CalendarStop? {
            try stage("-photodiary-calendar", value).calendar
        }
        #expect(try stop("daily") == .init(galleryId: "daily", year: nil, month: nil))
        #expect(try stop("daily/2024") == .init(galleryId: "daily", year: 2024, month: nil))
        #expect(try stop("daily/2024/6") == .init(galleryId: "daily", year: 2024, month: 6))
    }

    @Test func pinNotesMayHoldCommas() throws {
        let pinned = try stage("-photodiary-pins", "35.7,139.8,Ramen, the good one|35.6,139.7|bad")
        #expect(
            pinned.pins == [
                .init(latitude: 35.7, longitude: 139.8, note: "Ramen, the good one"),
                .init(latitude: 35.6, longitude: 139.7, note: ""),
            ])
    }

    @Test func anUnknownSheetIsIgnored() throws {
        #expect(try stage("-photodiary-sheet", "nope").sheet == nil)
        #expect(try stage("-photodiary-sheet", "pins").sheet == .pins)
    }
}
