import XCTest

@testable import PhotoDiaryCore

@MainActor
final class InstanceRegistryTests: XCTestCase {
    func testSeedsDemoOnFirstLaunchWithNoScope() {
        let registry = InstanceRegistry(seedingDemo: true)
        XCTAssertEqual(registry.instances.count, 1)
        XCTAssertNil(registry.scope, "first launch lands on the front page")
        XCTAssertNil(registry.activeInstance)
    }

    func testDoesNotSeedWhenAskedNotTo() {
        let registry = InstanceRegistry(seedingDemo: false)
        XCTAssertTrue(registry.instances.isEmpty)
        XCTAssertNil(registry.scope)
    }

    func testEnterOpensTheScope() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.enter(Scope(instanceId: "demo", galleryId: "g1"))
        XCTAssertEqual(registry.activeInstanceId, "demo")
        XCTAssertEqual(registry.scope?.galleryId, "g1")
        XCTAssertNotNil(registry.activeInstance)
    }

    func testEnterIgnoresUnknownInstance() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.enter(Scope(instanceId: "nonexistent"))
        XCTAssertNil(registry.scope)
    }

    func testLeaveScopeReturnsToTheFrontPage() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.enter(Scope(instanceId: "demo"))
        registry.leaveScope()
        XCTAssertNil(registry.scope)
        XCTAssertNil(registry.activeInstance)
    }

    func testAddDoesNotChangeTheScope() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.enter(Scope(instanceId: "demo"))
        registry.add(StubInstance(id: "stub-a"))
        XCTAssertEqual(registry.activeInstanceId, "demo")
    }

    func testAddReplacesDuplicateIdInPlace() {
        let registry = InstanceRegistry(seedingDemo: false)
        registry.add(StubInstance(id: "stub-a", displayName: "Original"))
        registry.add(StubInstance(id: "stub-a", displayName: "Replacement"))
        XCTAssertEqual(registry.instances.count, 1)
        XCTAssertEqual(registry.instances.first?.displayName, "Replacement")
    }

    func testRemovingTheScopedInstanceClearsTheScope() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.add(StubInstance(id: "stub-a"))
        registry.enter(Scope(instanceId: "stub-a"))
        registry.remove(id: "stub-a")
        XCTAssertNil(registry.scope)
        XCTAssertEqual(registry.instances.map(\.id), ["demo"])
    }

    func testAccessLostLeavesTheScopeWithAReason() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.enter(Scope(instanceId: "demo", galleryId: "g1"))
        XCTAssertTrue(registry.evictIfAccessLost(InstanceError.galleryNotFound("g1")))
        XCTAssertNil(registry.scope)
        XCTAssertEqual(registry.eviction?.reason, .galleryGone)
        XCTAssertEqual(registry.eviction?.scope.galleryId, "g1")
        XCTAssertEqual(registry.eviction?.instanceName, "Demo")
        XCTAssertTrue(
            registry.evictIfAccessLost(InstanceError.server(status: 403)) == false,
            "nothing to evict once out of the scope")
    }

    func testOtherFailuresKeepTheScope() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.enter(Scope(instanceId: "demo"))
        XCTAssertFalse(registry.evictIfAccessLost(InstanceError.transport("offline")))
        XCTAssertFalse(registry.evictIfAccessLost(InstanceError.server(status: 503)))
        XCTAssertNotNil(registry.scope)
        XCTAssertNil(registry.eviction)
    }

    func testEnteringAScopeClearsTheEviction() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.enter(Scope(instanceId: "demo"))
        registry.evictIfAccessLost(InstanceError.sessionExpired)
        XCTAssertEqual(registry.eviction?.reason, .sessionExpired)
        registry.enter(Scope(instanceId: "demo"))
        XCTAssertNil(registry.eviction)
    }

    func testRemovingAnotherInstanceKeepsTheScope() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.add(StubInstance(id: "stub-a"))
        registry.enter(Scope(instanceId: "demo"))
        registry.remove(id: "stub-a")
        XCTAssertEqual(registry.activeInstanceId, "demo")
    }
}

/// Bare-bones test double. Not a full Instance implementation — the
/// registry only touches id / displayName here.
private struct StubInstance: Instance {
    let id: String
    let displayName: String
    let isDemo = false

    init(id: String, displayName: String = "Stub") {
        self.id = id
        self.displayName = displayName
    }

    func listGalleries() async throws -> [Gallery] { [] }
    func listPhotos(inGallery galleryId: String) async throws -> [Photo] { [] }
    func getPhoto(id: String, inGallery galleryId: String) async throws -> Photo {
        throw InstanceError.notImplemented
    }
}
