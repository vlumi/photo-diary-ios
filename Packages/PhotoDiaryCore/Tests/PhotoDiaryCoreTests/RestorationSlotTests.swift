import Foundation
import Testing

@testable import PhotoDiaryCore

struct RestorationSlotTests {
    @Test func slotsKeepTheKeysAlreadySaved() {
        let scope = Scope(instanceId: "https://photos.example", galleryId: "daily")
        #expect(
            InMemoryRestorationStore.key(.camera, scope) == "camera.https://photos.example/daily")
        #expect(InMemoryRestorationStore.key(.tab, Scope(instanceId: "demo")) == "tab.demo/*")
    }

    @Test func aSavedMapCameraStillReadsAsARegion() throws {
        let saved = Data(
            #"{"latitude":35.68,"longitude":139.76,"latitudeDelta":0.2,"longitudeDelta":0.3}"#.utf8)
        let region = try JSONDecoder().decode(MapRegion.self, from: saved)
        #expect(
            region
                == MapRegion(
                    centerLatitude: 35.68, centerLongitude: 139.76, latitudeDelta: 0.2,
                    longitudeDelta: 0.3))
    }

    @Test func aSlotRoundTripsPerScope() {
        let store = InMemoryRestorationStore()
        let one = Scope(instanceId: "demo")
        store.save("calendar", .tab, in: one)
        #expect(store.load(String.self, .tab, in: one) == "calendar")
        #expect(store.load(String.self, .tab, in: Scope(instanceId: "demo", galleryId: "g")) == nil)
    }
}
