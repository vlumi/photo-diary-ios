import Foundation
import XCTest

@testable import PhotoDiaryCore

final class RemoteInstanceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubProtocol.reset()
    }

    func testListPhotosUsesCdnRootAndSortsByTimestamp() async throws {
        StubProtocol.handler = { request in
            switch request.url!.path {
            case "/api/v1/meta":
                return .init(status: 200, body: #"{"cdn":"https://cdn.example.test/photos"}"#)
            case "/api/v1/gallery-photos/g1/query":
                return .init(
                    status: 200,
                    body: """
                        [
                          {"id":"b.jpg","index":1,
                           "taken":{"instant":{"year":2024,"month":6,"day":2}},
                           "dimensions":{"original":{"width":1,"height":1},
                                         "thumbnail":{"width":1,"height":1}}},
                          {"id":"a.jpg","index":0,
                           "taken":{"instant":{"year":2024,"month":6,"day":1}},
                           "dimensions":{"original":{"width":1,"height":1},
                                         "thumbnail":{"width":1,"height":1}}}
                        ]
                        """
                )
            default:
                return .init(status: 404)
            }
        }
        let instance = RemoteInstance(host: "photos.example.test", api: stubbedAPI(), lang: "fi")
        let photos = try await instance.listPhotos(inGallery: "g1")

        XCTAssertEqual(photos.map(\.id), ["a.jpg", "b.jpg"])
        XCTAssertEqual(
            photos[0].thumbnailURL.absoluteString,
            "https://cdn.example.test/photos/thumbnail/a.jpg",
            "cdn without a trailing slash still roots the photo paths"
        )
        let query = StubProtocol.requests.first { $0.url!.path.hasSuffix("/query") }!
        XCTAssertEqual(query.httpMethod, "POST")
        XCTAssertEqual(query.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testPhotoRootFallsBackToApiHostAndIsResolvedOnce() async throws {
        StubProtocol.handler = { request in
            switch request.url!.path {
            case "/api/v1/meta": return .init(status: 200, body: "{}")
            case "/api/v1/gallery-photos/g1/query": return .init(status: 200, body: "[]")
            default: return .init(status: 404)
            }
        }
        let instance = RemoteInstance(host: "photos.example.test", api: stubbedAPI())
        _ = try await instance.listPhotos(inGallery: "g1")
        _ = try await instance.listPhotos(inGallery: "g1")
        let metaCalls = StubProtocol.requests.filter { $0.url!.path == "/api/v1/meta" }
        XCTAssertEqual(metaCalls.count, 1)
    }

    private func stubEmptyGallery() {
        StubProtocol.handler = { request in
            switch request.url!.path {
            case "/api/v1/meta": return .init(status: 200, body: "{}")
            case "/api/v1/gallery-photos/g1/query":
                return .init(
                    status: 200,
                    body: """
                        [{"id":"a.jpg","index":0,"taken":{"instant":{"year":2024,"month":6,"day":1}},
                          "dimensions":{"original":{"width":1,"height":1},
                                        "thumbnail":{"width":1,"height":1}}}]
                        """
                )
            default: return .init(status: 404)
            }
        }
    }

    func testListPhotosIsServedFromCacheWithinTTL() async throws {
        stubEmptyGallery()
        let instance = RemoteInstance(host: "photos.example.test", api: stubbedAPI())
        _ = try await instance.listPhotos(inGallery: "g1")
        _ = try await instance.listPhotos(inGallery: "g1")
        let queries = StubProtocol.requests.filter { $0.url!.path.hasSuffix("/query") }
        XCTAssertEqual(queries.count, 1)
    }

    func testCacheExpiresAfterTTL() async throws {
        stubEmptyGallery()
        let clock = FakeClock()
        let instance = RemoteInstance(
            host: "photos.example.test", api: stubbedAPI(), now: { clock.now })
        _ = try await instance.listPhotos(inGallery: "g1")
        clock.advance(by: RemoteInstance.photoCacheTTL + 1)
        _ = try await instance.listPhotos(inGallery: "g1")
        let queries = StubProtocol.requests.filter { $0.url!.path.hasSuffix("/query") }
        XCTAssertEqual(queries.count, 2)
    }

    func testGetPhotoIsAnsweredFromTheCachedListWhenPresent() async throws {
        stubEmptyGallery()  // the single-photo endpoint 404s here on purpose
        let instance = RemoteInstance(host: "photos.example.test", api: stubbedAPI())
        _ = try await instance.listPhotos(inGallery: "g1")
        let photo = try await instance.getPhoto(id: "a.jpg", inGallery: "g1")
        XCTAssertEqual(photo.id, "a.jpg")
        XCTAssertFalse(
            StubProtocol.requests.contains { $0.url!.path == "/api/v1/gallery-photos/g1/a.jpg" })
    }

    func testIdentityIsTheHost() {
        let instance = RemoteInstance(host: "photos.example.test", api: stubbedAPI())
        XCTAssertEqual(instance.id, "photos.example.test")
        XCTAssertEqual(instance.displayName, "photos.example.test")
        XCTAssertFalse(instance.isDemo)
    }
}

private final class FakeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date()
    var now: Date { lock.withLock { current } }
    func advance(by seconds: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(seconds) }
    }
}
