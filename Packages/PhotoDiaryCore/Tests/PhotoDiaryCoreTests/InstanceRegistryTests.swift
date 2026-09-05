import XCTest
@testable import PhotoDiaryCore

@MainActor
final class InstanceRegistryTests: XCTestCase {
    func testSeedsDemoOnFirstLaunch() {
        let registry = InstanceRegistry(seedingDemo: true)
        XCTAssertEqual(registry.instances.count, 1)
        XCTAssertEqual(registry.activeInstanceId, "demo")
        XCTAssertNotNil(registry.activeInstance)
    }

    func testDoesNotSeedWhenAskedNotTo() {
        let registry = InstanceRegistry(seedingDemo: false)
        XCTAssertTrue(registry.instances.isEmpty)
        XCTAssertNil(registry.activeInstanceId)
    }

    func testAddPromotesToActiveWhenNothingElseIsActive() {
        let registry = InstanceRegistry(seedingDemo: false)
        registry.add(DemoInstance())
        XCTAssertEqual(registry.activeInstanceId, "demo")
    }

    func testAddKeepsExistingActiveIfAlreadySet() {
        let registry = InstanceRegistry(seedingDemo: true)
        // Already active on "demo". Adding a second instance with a
        // different id must not shift the active pointer.
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

    func testSetActiveIgnoresUnknownId() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.setActive("nonexistent")
        XCTAssertEqual(registry.activeInstanceId, "demo")
    }

    func testRemoveReassignsActiveToTheFirstRemaining() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.add(StubInstance(id: "stub-a"))
        registry.setActive("stub-a")
        registry.remove(id: "stub-a")
        XCTAssertEqual(registry.activeInstanceId, "demo")
    }

    func testRemoveLastLeavesActiveNil() {
        let registry = InstanceRegistry(seedingDemo: true)
        registry.remove(id: "demo")
        XCTAssertNil(registry.activeInstanceId)
        XCTAssertNil(registry.activeInstance)
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
