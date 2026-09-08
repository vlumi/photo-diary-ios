import Foundation
import XCTest

@testable import PhotoDiaryCore

final class PairingServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubProtocol.reset()
    }

    private func factory(store: InMemorySessionStore) -> RemoteInstanceFactory {
        RemoteInstanceFactory(sessionStore: store) {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [StubProtocol.self]
            return config
        }
    }

    func testPairsConsumesTicketVerifiesSessionAndPersistsCookies() async throws {
        StubProtocol.handler = { request in
            switch request.url!.path {
            case "/api/v1/tokens/sso":
                return .init(
                    status: 302,
                    headers: [
                        "Location": "/",
                        "Set-Cookie": "pd_access=a1; Path=/, pd_refresh=r1; Path=/",
                    ]
                )
            case "/api/v1/tokens":
                return .init(
                    status: 200,
                    body: #"{"id":"userA","isAdmin":false,"editorGalleries":[]}"#
                )
            default:
                return .init(status: 404)
            }
        }
        let store = InMemorySessionStore()
        let service = PairingService(factory: factory(store: store))
        let instance = try await service.pair(
            PairingTicket(host: "photos.example.test", token: "tkt")
        )

        XCTAssertEqual(instance.id, "https://photos.example.test")
        XCTAssertEqual(StubProtocol.requests[0].url!.scheme, "https")
        let sso = StubProtocol.requests[0]
        XCTAssertEqual(sso.url!.path, "/api/v1/tokens/sso")
        XCTAssertTrue(sso.url!.query!.contains("token=tkt"))
        XCTAssertNil(sso.value(forHTTPHeaderField: "Cookie"), "fresh pairing sends no cookies")
        XCTAssertEqual(
            StubProtocol.requests[1].value(forHTTPHeaderField: "Cookie"),
            "pd_access=a1; pd_refresh=r1",
            "the verify call carries the cookies the 302 set"
        )
        XCTAssertEqual(
            try store.load(host: "https://photos.example.test"),
            SessionCookies(access: "a1", refresh: "r1"),
            "cookies reached the store through the factory hook"
        )
    }

    func testRefusedTicketThrowsRejectedAndStoresNothing() async {
        StubProtocol.handler = { _ in .init(status: 401, body: #"{"error":"Invalid token"}"#) }
        let store = InMemorySessionStore()
        let service = PairingService(factory: factory(store: store))
        do {
            _ = try await service.pair(PairingTicket(host: "photos.example.test", token: "used"))
            XCTFail("expected rejected")
        } catch PairingError.rejected(let status) {
            XCTAssertEqual(status, 401)
        } catch {
            XCTFail("wrong error: \(error)")
        }
        XCTAssertNil(try? store.load(host: "https://photos.example.test"))
        XCTAssertEqual(
            StubProtocol.requests.count, 1,
            "no refresh attempt without a refresh cookie"
        )
    }

    func testHttpTicketTalksPlainHttp() async throws {
        StubProtocol.handler = { request in
            if request.url!.path == "/api/v1/tokens/sso" {
                return .init(
                    status: 302,
                    headers: ["Set-Cookie": "pd_access=a; Path=/, pd_refresh=r; Path=/"]
                )
            }
            return .init(status: 200, body: #"{"id":"u","isAdmin":false,"editorGalleries":[]}"#)
        }
        let service = PairingService(factory: factory(store: InMemorySessionStore()))
        let instance = try await service.pair(
            PairingTicket(host: "localhost:3000", token: "t", scheme: "http")
        )
        XCTAssertEqual(instance.id, "http://localhost:3000")
        XCTAssertTrue(
            StubProtocol.requests[0].url!.absoluteString.hasPrefix("http://localhost:3000/")
        )
    }

    func testRedirectWithoutCookiesIsNoSession() async {
        StubProtocol.handler = { _ in .init(status: 302, headers: ["Location": "/"]) }
        let service = PairingService(factory: factory(store: InMemorySessionStore()))
        do {
            _ = try await service.pair(PairingTicket(host: "photos.example.test", token: "t"))
            XCTFail("expected noSession")
        } catch PairingError.noSession {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
