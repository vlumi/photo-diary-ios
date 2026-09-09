#if canImport(SwiftData)
import Foundation
import SwiftData
import XCTest

@testable import PhotoDiaryCore

@MainActor
final class TodoPinStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: TodoPinStore!

    override func setUp() async throws {
        // In-memory store so tests don't touch the on-disk container
        // and each test starts empty.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: TodoPin.self, configurations: config)
        store = TodoPinStore(context: container.mainContext)
    }

    func testCreatePersistsAndReturnsPin() throws {
        let pin = try store.create(latitude: 35.0, longitude: 139.0, note: "coffee shop")
        XCTAssertEqual(pin.latitude, 35.0)
        XCTAssertEqual(pin.longitude, 139.0)
        XCTAssertEqual(pin.note, "coffee shop")
        XCTAssertEqual(try store.all().count, 1)
    }

    func testUpdateNoteBumpsUpdatedAt() throws {
        let pin = try store.create(latitude: 0, longitude: 0)
        let originalUpdatedAt = pin.updatedAt
        // Sleep a hair so the timestamp actually advances.
        Thread.sleep(forTimeInterval: 0.01)
        try store.updateNote(pin, note: "new note")
        XCTAssertEqual(pin.note, "new note")
        XCTAssertGreaterThan(pin.updatedAt, originalUpdatedAt)
    }

    func testDeleteRemovesFromStore() throws {
        let a = try store.create(latitude: 1, longitude: 1)
        _ = try store.create(latitude: 2, longitude: 2)
        try store.delete(a)
        let remaining = try store.all()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.latitude, 2)
    }

    func testAllOrdersStarredFirstThenLastEdited() throws {
        let a = try store.create(latitude: 1, longitude: 1)
        Thread.sleep(forTimeInterval: 0.01)
        let b = try store.create(latitude: 2, longitude: 2)
        Thread.sleep(forTimeInterval: 0.01)
        let c = try store.create(latitude: 3, longitude: 3)
        XCTAssertEqual(try store.all().map(\.id), [c.id, b.id, a.id])

        try store.setStarred(a, true)
        Thread.sleep(forTimeInterval: 0.01)
        try store.updateNote(b, note: "edited")
        XCTAssertEqual(try store.all().map(\.id), [a.id, b.id, c.id])
        XCTAssertLessThan(a.updatedAt, b.updatedAt, "starring is not an edit")
    }

    func testMoveUpdatesCoordinatesAndBumpsUpdatedAt() throws {
        let pin = try store.create(latitude: 1, longitude: 1, note: "keep me")
        let before = pin.updatedAt
        Thread.sleep(forTimeInterval: 0.01)
        try store.move(pin, latitude: 35.68, longitude: 139.76)
        XCTAssertEqual(pin.latitude, 35.68)
        XCTAssertEqual(pin.longitude, 139.76)
        XCTAssertEqual(pin.note, "keep me")
        XCTAssertGreaterThan(pin.updatedAt, before)
    }
}
#endif
