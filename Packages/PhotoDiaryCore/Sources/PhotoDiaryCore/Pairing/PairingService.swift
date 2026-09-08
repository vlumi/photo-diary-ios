import Foundation

public enum PairingError: Error, Sendable, LocalizedError {
    /// The server refused the ticket: expired, already used, wrong host.
    case rejected(status: Int)
    /// The consume succeeded but set no session — server misconfigured.
    case noSession

    public var errorDescription: String? {
        switch self {
        case .rejected(let status) where status == 401:
            return "The pairing code was refused — it may have expired or already been used."
        case .rejected(let status):
            return "The server refused the pairing code (HTTP \(status))."
        case .noSession:
            return "The server accepted the code but returned no session."
        }
    }
}

/// Turns a pairing ticket into a working RemoteInstance: consumes the
/// one-shot SSO ticket (the 302's Set-Cookie is the session), then
/// proves the session with GET /tokens before handing the instance
/// back. Cookies persist through the factory's hook as they arrive.
public struct PairingService: Sendable {
    private let factory: RemoteInstanceFactory

    public init(factory: RemoteInstanceFactory) {
        self.factory = factory
    }

    public func pair(_ ticket: PairingTicket) async throws -> RemoteInstance {
        let api = factory.makeAPI(origin: ticket.origin, cookies: SessionCookies())

        var components = URLComponents(url: api.baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/v1/tokens/sso"
        components.queryItems = [
            URLQueryItem(name: "token", value: ticket.token),
            URLQueryItem(name: "redirect", value: "/"),
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"

        let (_, response) = try await api.send(request)
        guard response.statusCode == 302 || (200..<300).contains(response.statusCode) else {
            throw PairingError.rejected(status: response.statusCode)
        }
        guard await api.currentCookies.refresh != nil else {
            throw PairingError.noSession
        }
        let _: SessionIdentity = try await api.get("/api/v1/tokens")
        return factory.make(origin: ticket.origin, api: api)
    }
}

struct SessionIdentity: Decodable, Sendable {
    let id: String
    let isAdmin: Bool
}
