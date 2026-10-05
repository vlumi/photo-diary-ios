import Foundation

/// A 401 gets one refresh and a single retry; a refused refresh surfaces
/// as `InstanceError.sessionExpired`, so the UI can ask for a re-pair.
public actor PhotoDiaryAPI {
    public let baseURL: URL
    private let session: URLSession
    private var cookies: SessionCookies
    private let onCookiesChanged: (@Sendable (SessionCookies) -> Void)?
    private var persisting: Bool

    /// `persisting: false` holds `onCookiesChanged` back until
    /// `startPersisting()`.
    public init(
        origin: String,
        cookies: SessionCookies = SessionCookies(),
        onCookiesChanged: (@Sendable (SessionCookies) -> Void)? = nil,
        persisting: Bool = true,
        configuration: URLSessionConfiguration = .ephemeral
    ) {
        self.persisting = persisting
        self.baseURL = URL(string: origin + "/")!
        self.cookies = cookies
        self.onCookiesChanged = onCookiesChanged
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        // Redirects are never followed: the only endpoint that issues
        // one is the SSO consume, and its Set-Cookie rides on the 302
        // itself — following it would land on the SPA's HTML.
        self.session = URLSession(
            configuration: configuration,
            delegate: NoRedirectDelegate(),
            delegateQueue: nil
        )
    }

    public var currentCookies: SessionCookies { cookies }

    /// Hands the session to the hook from now on, starting with the
    /// cookies held now.
    public func startPersisting() {
        persisting = true
        onCookiesChanged?(cookies)
    }

    public func stopPersisting() {
        persisting = false
    }

    private func cookiesChanged() {
        if persisting { onCookiesChanged?(cookies) }
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await perform(request)
        guard response.statusCode == 401, cookies.refresh != nil else {
            return (data, response)
        }
        try await refresh()
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var request = request
        if let header = cookies.headerValue {
            request.setValue(header, forHTTPHeaderField: "Cookie")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw InstanceError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw InstanceError.transport("non-HTTP response")
        }
        capture(http, for: request.url ?? baseURL)
        return (data, http)
    }

    private func refresh() async throws {
        // Sent here rather than through the generated client's
        // `refreshSession`, which would come back through this transport
        // and its own refresh-on-401.
        var request = URLRequest(url: url("/api/v1/tokens/refresh"))
        request.httpMethod = "POST"
        let (_, response) = try await perform(request)
        guard (200..<300).contains(response.statusCode) else {
            // The refresh handle itself was rejected — nothing left to
            // retry with. Drop both cookies so the next attempt doesn't
            // loop, and let the UI route to re-pairing.
            cookies = SessionCookies()
            cookiesChanged()
            throw InstanceError.sessionExpired
        }
    }

    private func capture(_ response: HTTPURLResponse, for url: URL) {
        let before = cookies
        cookies.apply(response: response, url: url)
        if cookies != before {
            cookiesChanged()
        }
    }

    private func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        return components.url!
    }
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
