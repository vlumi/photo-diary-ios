import Foundation
import XCTest

@testable import PhotoDiaryCore

// Scripted HTTP stand-in: each test installs a handler that maps a
// request to (status, headers, body) and records what was sent.
// Tests are serial, so the static state is uncontended.
class StubProtocol: URLProtocol {
    struct Reply {
        var status: Int
        var headers: [String: String] = [:]
        var body: String = ""
    }

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> Reply)?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    static func reset() {
        handler = nil
        requests = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        let reply = Self.handler!(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: reply.status,
            httpVersion: "HTTP/1.1",
            headerFields: reply.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

func stubbedAPI(
    cookies: SessionCookies = SessionCookies(),
    onCookiesChanged: (@Sendable (SessionCookies) -> Void)? = nil
) -> PhotoDiaryAPI {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubProtocol.self]
    return PhotoDiaryAPI(
        origin: "https://photos.example.test",
        cookies: cookies,
        onCookiesChanged: onCookiesChanged,
        configuration: config
    )
}

private struct GalleryRow: Decodable, Sendable {
    let id: String
}

final class PhotoDiaryAPITests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubProtocol.reset()
    }

    func testCapturesSetCookieAndSendsItBack() async throws {
        StubProtocol.handler = { _ in
            if StubProtocol.requests.count == 1 {
                return .init(
                    status: 200,
                    headers: [
                        "Set-Cookie": "pd_access=a1; Path=/; HttpOnly, "
                            + "pd_refresh=r1; Path=/; HttpOnly"
                    ],
                    body: "[]"
                )
            }
            return .init(status: 200, body: "[]")
        }
        let api = stubbedAPI()
        let _: [GalleryRow] = try await api.get("/api/v1/galleries")
        let _: [GalleryRow] = try await api.get("/api/v1/galleries")

        XCTAssertNil(StubProtocol.requests[0].value(forHTTPHeaderField: "Cookie"))
        XCTAssertEqual(
            StubProtocol.requests[1].value(forHTTPHeaderField: "Cookie"),
            "pd_access=a1; pd_refresh=r1"
        )
        let current = await api.currentCookies
        XCTAssertEqual(current, SessionCookies(access: "a1", refresh: "r1"))
    }

    func testRefreshesOnce401ThenRetries() async throws {
        StubProtocol.handler = { request in
            switch (request.httpMethod, request.url!.path) {
            case ("GET", "/api/v1/galleries") where StubProtocol.requests.count == 1:
                return .init(status: 401, body: #"{"error":"Token expired"}"#)
            case ("POST", "/api/v1/tokens/refresh"):
                return .init(
                    status: 200,
                    headers: ["Set-Cookie": "pd_access=a2; Path=/, pd_refresh=r2; Path=/"],
                    body: #"{"id":"u","isAdmin":false,"editorGalleries":[]}"#
                )
            case ("GET", "/api/v1/galleries"):
                return .init(status: 200, body: #"[{"id":"g1"}]"#)
            default:
                return .init(status: 500)
            }
        }
        let api = stubbedAPI(cookies: SessionCookies(access: "stale", refresh: "r1"))
        let rows: [GalleryRow] = try await api.get("/api/v1/galleries")

        XCTAssertEqual(rows.map(\.id), ["g1"])
        XCTAssertEqual(
            StubProtocol.requests.map { "\($0.httpMethod!) \($0.url!.path)" },
            ["GET /api/v1/galleries", "POST /api/v1/tokens/refresh", "GET /api/v1/galleries"]
        )
        XCTAssertEqual(
            StubProtocol.requests[2].value(forHTTPHeaderField: "Cookie"),
            "pd_access=a2; pd_refresh=r2"
        )
    }

    func testRejectedRefreshThrowsSessionExpiredAndClearsCookies() async {
        StubProtocol.handler = { _ in .init(status: 401) }
        let changes = Changes()
        let api = stubbedAPI(
            cookies: SessionCookies(access: "stale", refresh: "dead"),
            onCookiesChanged: { changes.record($0) }
        )
        do {
            let _: [GalleryRow] = try await api.get("/api/v1/galleries")
            XCTFail("expected sessionExpired")
        } catch InstanceError.sessionExpired {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
        let current = await api.currentCookies
        XCTAssertTrue(current.isEmpty)
        XCTAssertEqual(changes.last, SessionCookies())
        XCTAssertEqual(StubProtocol.requests.count, 2, "one call + one refresh, no retry")
    }

    func testNoRefreshAttemptWithoutRefreshCookie() async {
        StubProtocol.handler = { _ in .init(status: 401) }
        let api = stubbedAPI()
        do {
            let _: [GalleryRow] = try await api.get("/api/v1/galleries")
            XCTFail("expected sessionExpired")
        } catch InstanceError.sessionExpired {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
        XCTAssertEqual(StubProtocol.requests.count, 1)
    }

    func testRedirectIsNotFollowedAndItsCookiesAreCaptured() async throws {
        // The SSO consume answers 302 with the session cookies on the
        // redirect itself; following it would land on the SPA's HTML.
        StubProtocol.handler = { _ in
            .init(
                status: 302,
                headers: [
                    "Location": "/",
                    "Set-Cookie": "pd_access=a1; Path=/, pd_refresh=r1; Path=/",
                ]
            )
        }
        let api = stubbedAPI()
        let url = URL(string: "https://photos.example.test/api/v1/tokens/sso?token=t")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (_, response) = try await api.send(request)
        XCTAssertEqual(response.statusCode, 302)
        XCTAssertEqual(StubProtocol.requests.count, 1)
        let current = await api.currentCookies
        XCTAssertEqual(current, SessionCookies(access: "a1", refresh: "r1"))
    }

    func testClearedCookieBecomesNil() async throws {
        StubProtocol.handler = { _ in
            .init(
                status: 200,
                headers: [
                    "Set-Cookie": "pd_access=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
                ],
                body: "[]"
            )
        }
        let api = stubbedAPI(cookies: SessionCookies(access: "a1", refresh: "r1"))
        let _: [GalleryRow] = try await api.get("/api/v1/galleries")
        let current = await api.currentCookies
        XCTAssertEqual(current, SessionCookies(access: nil, refresh: "r1"))
    }
}

private final class Changes: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [SessionCookies] = []
    func record(_ value: SessionCookies) {
        lock.withLock { values.append(value) }
    }
    var last: SessionCookies? { lock.withLock { values.last } }
}
