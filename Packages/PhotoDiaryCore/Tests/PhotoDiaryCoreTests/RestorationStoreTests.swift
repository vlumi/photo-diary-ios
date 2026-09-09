import Foundation
import Testing

@testable import PhotoDiaryCore

struct RestorationStoreTests {
    private struct Camera: Codable, Equatable, Sendable {
        let latitude: Double
        let longitude: Double
    }

    @Test func inMemoryRoundTripsAndClears() {
        let store = InMemoryRestorationStore()
        store.save(Camera(latitude: 35.6, longitude: 139.7), forKey: "camera.a")
        #expect(
            store.load(Camera.self, forKey: "camera.a") == Camera(latitude: 35.6, longitude: 139.7))
        #expect(store.load(Camera.self, forKey: "camera.b") == nil)
        store.save(nil as Camera?, forKey: "camera.a")
        #expect(store.load(Camera.self, forKey: "camera.a") == nil)
    }

    @Test func userDefaultsRoundTripsUnderItsOwnPrefix() throws {
        let suite = "RestorationStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsRestorationStore(suiteName: suite)
        store.save(["a", "b"], forKey: "path")
        #expect(store.load([String].self, forKey: "path") == ["a", "b"])
        #expect(defaults.data(forKey: "restore.path") != nil)
    }

    @Test func scopeKeyDistinguishesGalleryFromAll() {
        #expect(Scope(instanceId: "demo").key == "demo/*")
        #expect(Scope(instanceId: "demo", galleryId: "g1").key == "demo/g1")
    }
}
