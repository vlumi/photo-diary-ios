import Foundation

/// The two HttpOnly cookies a server session consists of. Managed by
/// hand instead of the system cookie jar so each RemoteInstance keeps
/// its own pair, nothing leaks across hosts, and the values can be
/// persisted to the Keychain as plain strings.
///
/// `pd_access` is a short-lived JWT; `pd_refresh` is the 90-day
/// session handle the refresh endpoint rotates. Either may be nil —
/// no access cookie just means the next request will 401 and refresh.
public struct SessionCookies: Hashable, Sendable, Codable {
    public static let accessName = "pd_access"
    public static let refreshName = "pd_refresh"

    public var access: String?
    public var refresh: String?

    public init(access: String? = nil, refresh: String? = nil) {
        self.access = access
        self.refresh = refresh
    }

    public var isEmpty: Bool { access == nil && refresh == nil }

    /// Value for an outgoing `Cookie` header, or nil when there's
    /// nothing to send.
    var headerValue: String? {
        var parts: [String] = []
        if let access { parts.append("\(Self.accessName)=\(access)") }
        if let refresh { parts.append("\(Self.refreshName)=\(refresh)") }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }

    /// Fold a response's Set-Cookie headers in. A cookie the server
    /// clears (past expiry, as `clearCookie` emits) becomes nil.
    /// Unknown cookie names are ignored.
    mutating func apply(response: HTTPURLResponse, url: URL) {
        guard let setCookie = response.value(forHTTPHeaderField: "Set-Cookie") else { return }
        let cookies = HTTPCookie.cookies(
            withResponseHeaderFields: ["Set-Cookie": setCookie],
            for: url
        )
        for cookie in cookies {
            let cleared = cookie.expiresDate.map { $0 < Date() } ?? false
            let value: String? = cleared || cookie.value.isEmpty ? nil : cookie.value
            switch cookie.name {
            case Self.accessName: access = value
            case Self.refreshName: refresh = value
            default: break
            }
        }
    }
}
