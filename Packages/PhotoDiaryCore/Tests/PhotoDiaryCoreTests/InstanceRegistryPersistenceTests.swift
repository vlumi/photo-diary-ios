import Foundation
import XCTest

@testable import PhotoDiaryCore

@MainActor
final class InstanceRegistryPersistenceTests: XCTestCase {
    func testFirstLaunchSeedsDemoAndPersistsIt() {
        let persistence = InMemoryInstancePersistence()
        let registry = InstanceRegistry(
            persistence: persistence, sessionStore: InMemorySessionStore()
        )
        XCTAssertEqual(registry.instances.map(\.id), ["demo"])
        XCTAssertEqual(persistence.loadInstanceIds(), ["demo"])
        XCTAssertEqual(persistence.loadActiveId(), "demo")
    }

    func testRestoresRemoteHostsAndActiveFromPersistence() {
        let persistence = InMemoryInstancePersistence(
            ids: ["demo", "photos.example.test"], active: "photos.example.test")
        let store = InMemorySessionStore()
        try? store.save(SessionCookies(access: "a", refresh: "r"), host: "photos.example.test")
        let registry = InstanceRegistry(persistence: persistence, sessionStore: store)
        XCTAssertEqual(registry.instances.map(\.id), ["demo", "photos.example.test"])
        XCTAssertEqual(registry.activeInstanceId, "photos.example.test")
        XCTAssertFalse(registry.activeInstance?.isDemo ?? true)
    }

    func testStaleActiveIdFallsBackToFirstInstance() {
        let persistence = InMemoryInstancePersistence(ids: ["demo"], active: "gone.example")
        let registry = InstanceRegistry(
            persistence: persistence, sessionStore: InMemorySessionStore()
        )
        XCTAssertEqual(registry.activeInstanceId, "demo")
        XCTAssertEqual(persistence.loadActiveId(), "demo")
    }

    func testRemovingDemoIsRememberedAcrossLaunches() {
        let persistence = InMemoryInstancePersistence()
        let store = InMemorySessionStore()
        InstanceRegistry(persistence: persistence, sessionStore: store).remove(id: "demo")
        let relaunched = InstanceRegistry(persistence: persistence, sessionStore: store)
        XCTAssertTrue(relaunched.instances.isEmpty, "removed demo must not be re-seeded")
    }

    func testRemovingARemoteInstanceDeletesItsSession() throws {
        let persistence = InMemoryInstancePersistence(ids: ["photos.example.test"], active: nil)
        let store = InMemorySessionStore()
        try store.save(SessionCookies(access: "a", refresh: "r"), host: "photos.example.test")
        let registry = InstanceRegistry(persistence: persistence, sessionStore: store)
        registry.remove(id: "photos.example.test")
        XCTAssertNil(try store.load(host: "photos.example.test"))
        XCTAssertEqual(persistence.loadInstanceIds(), [])
    }

    func testSetActivePersists() {
        let persistence = InMemoryInstancePersistence(ids: ["demo", "h.example"], active: "demo")
        let registry = InstanceRegistry(
            persistence: persistence, sessionStore: InMemorySessionStore()
        )
        registry.setActive("h.example")
        XCTAssertEqual(persistence.loadActiveId(), "h.example")
    }
}
