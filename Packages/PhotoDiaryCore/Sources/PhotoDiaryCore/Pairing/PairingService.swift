import Foundation

public enum PairingError: Error, Sendable, LocalizedError {
    /// The server refused the ticket: expired, already used, wrong host.
    case rejected(status: Int)
    /// The consume succeeded but set no session — server misconfigured.
    case noSession

    public var errorDescription: String? {
        switch self {
        case .rejected(let status) where status == 401:
            return String(
                localized:
                    "The pairing code was refused — it may have expired or already been used.",
                bundle: .module)
        case .rejected(let status):
            return String(
                localized: "The server refused the pairing code (HTTP \(status)).",
                bundle: .module)
        case .noSession:
            return String(
                localized: "The server accepted the code but returned no session.",
                bundle: .module)
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
        let client = PhotoDiaryClient(api: api)
        // The server answers with a redirect into the site, carrying the
        // session cookies; the transport doesn't follow it.
        try await client.call { client in
            switch try await client.consumeTicket(query: .init(token: ticket.token, redirect: "/"))
            {
            case .found: return
            case .unauthorized: throw PairingError.rejected(status: 401)
            case .undocumented(let status, _) where (200..<300).contains(status): return
            case .undocumented(let status, _): throw PairingError.rejected(status: status)
            }
        }
        guard await api.currentCookies.refresh != nil else {
            throw PairingError.noSession
        }
        // Proves the session before the instance is handed back.
        try await client.call { client in
            switch try await client.getSession() {
            case .ok: return
            case .unauthorized, .forbidden: throw InstanceError.sessionExpired
            case .undocumented(let status, _): throw unexpected(status: status)
            }
        }
        return factory.make(origin: ticket.origin, api: api)
    }
}
