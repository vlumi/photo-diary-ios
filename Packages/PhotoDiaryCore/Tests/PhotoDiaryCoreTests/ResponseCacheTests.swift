import Foundation
import Testing

@testable import PhotoDiaryCore

struct ResponseCacheTests {
    private func temporaryCache() -> ResponseCache {
        ResponseCache(
            root: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
    }

    @Test func roundTripsPerOriginAndKey() {
        let cache = temporaryCache()
        cache.save(Data("[1]".utf8), origin: "https://a.example", key: "photos/g1")
        #expect(cache.load(origin: "https://a.example", key: "photos/g1") == Data("[1]".utf8))
        #expect(cache.load(origin: "https://a.example", key: "photos/g2") == nil)
        #expect(cache.load(origin: "https://b.example", key: "photos/g1") == nil)
    }

    @Test func clearDropsOneOriginOnly() {
        let cache = temporaryCache()
        cache.save(Data("a".utf8), origin: "https://a.example", key: "galleries")
        cache.save(Data("b".utf8), origin: "https://b.example", key: "galleries")
        cache.clear(origin: "https://a.example")
        #expect(cache.load(origin: "https://a.example", key: "galleries") == nil)
        #expect(cache.load(origin: "https://b.example", key: "galleries") == Data("b".utf8))
    }

    @Test func namesStayFlatAndSafe() {
        #expect(
            ResponseCache.fileSafe("https://photos.example.test:8443")
                == "https___photos.example.test_8443")
        #expect(ResponseCache.fileSafe("photos/g1") == "photos_g1")
    }
}
