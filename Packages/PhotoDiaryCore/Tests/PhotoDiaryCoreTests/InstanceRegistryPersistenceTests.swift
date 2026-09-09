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
        XCTAssertNil(persistence.loadScope())
    }

    func testRestoresRemoteHostsAndScopeFromPersistence() {
        let persistence = InMemoryInstancePersistence(
            ids: ["demo", "https://photos.example.test"],
            scope: Scope(instanceId: "https://photos.example.test", galleryId: "family"))
        let store = InMemorySessionStore()
        try? store.save(
            SessionCookies(access: "a", refresh: "r"), host: "https://photos.example.test")
        let registry = InstanceRegistry(persistence: persistence, sessionStore: store)
        XCTAssertEqual(registry.instances.map(\.id), ["demo", "https://photos.example.test"])
        XCTAssertEqual(registry.activeInstanceId, "https://photos.example.test")
        XCTAssertEqual(registry.scope?.galleryId, "family")
        XCTAssertFalse(registry.activeInstance?.isDemo ?? true)
    }

    func testStaleScopeFallsBackToTheFrontPage() {
        let persistence = InMemoryInstancePersistence(
            ids: ["demo"], scope: Scope(instanceId: "gone.example"))
        let registry = InstanceRegistry(
            persistence: persistence, sessionStore: InMemorySessionStore()
        )
        XCTAssertNil(registry.scope)
        XCTAssertNil(persistence.loadScope())
    }

    func testRemovingDemoIsRememberedAcrossLaunches() {
        let persistence = InMemoryInstancePersistence()
        let store = InMemorySessionStore()
        InstanceRegistry(persistence: persistence, sessionStore: store).remove(id: "demo")
        let relaunched = InstanceRegistry(persistence: persistence, sessionStore: store)
        XCTAssertTrue(relaunched.instances.isEmpty, "removed demo must not be re-seeded")
    }

    func testRemovingARemoteInstanceDeletesItsSession() throws {
        let persistence = InMemoryInstancePersistence(ids: ["https://photos.example.test"])
        let store = InMemorySessionStore()
        try store.save(
            SessionCookies(access: "a", refresh: "r"), host: "https://photos.example.test")
        let registry = InstanceRegistry(persistence: persistence, sessionStore: store)
        registry.remove(id: "https://photos.example.test")
        XCTAssertNil(try store.load(host: "https://photos.example.test"))
        XCTAssertEqual(persistence.loadInstanceIds(), [])
    }

    func testEvictionClearsWhatWasCachedForTheScope() throws {
        let cache = ResponseCache(
            root: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        let origin = "https://photos.example.test"
        cache.save(Data("[]".utf8), origin: origin, key: "galleries")
        cache.save(Data("[]".utf8), origin: origin, key: "photos/g1")
        cache.save(Data("[]".utf8), origin: origin, key: "photos/g2")
        let registry = InstanceRegistry(
            persistence: InMemoryInstancePersistence(ids: [origin]),
            sessionStore: InMemorySessionStore(), cache: cache)

        registry.enter(Scope(instanceId: origin, galleryId: "g1"))
        registry.evictIfAccessLost(InstanceError.galleryNotFound("g1"))
        XCTAssertNil(cache.load(origin: origin, key: "photos/g1"), "the gone gallery is dropped")
        XCTAssertNotNil(cache.load(origin: origin, key: "photos/g2"), "the rest stays")

        registry.enter(Scope(instanceId: origin))
        registry.evictIfAccessLost(InstanceError.sessionExpired)
        XCTAssertNil(cache.load(origin: origin, key: "galleries"), "a dead session drops it all")
        XCTAssertNil(cache.load(origin: origin, key: "photos/g2"))
    }

    func testEnterAndLeavePersist() {
        let persistence = InMemoryInstancePersistence(
            ids: ["demo", "h.example"], scope: Scope(instanceId: "h.example"))
        let registry = InstanceRegistry(
            persistence: persistence, sessionStore: InMemorySessionStore()
        )
        // A pre-origin id is read as https and persisted canonically.
        XCTAssertEqual(registry.instances.map(\.id), ["demo", "https://h.example"])
        XCTAssertEqual(persistence.loadScope()?.instanceId, "https://h.example")
        registry.enter(Scope(instanceId: "demo", galleryId: "g"))
        XCTAssertEqual(persistence.loadScope(), Scope(instanceId: "demo", galleryId: "g"))
        registry.leaveScope()
        XCTAssertNil(persistence.loadScope())
    }
}
