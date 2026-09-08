import Foundation

/// HTTP client for one photo-diary host. Owns that host's session
/// cookies, attaches them to every request, folds Set-Cookie back in,
/// and runs the refresh loop: a 401 triggers one POST /tokens/refresh
/// and a single retry; a refused refresh surfaces as
/// `InstanceError.sessionExpired` so the UI can ask for a re-pair.
///
/// The system cookie jar is disabled on the session so hosts can't
/// share state and the cookie values stay ours to persist.
public actor PhotoDiaryAPI {
    public let baseURL: URL
    private let session: URLSession
    private var cookies: SessionCookies
    private let onCookiesChanged: (@Sendable (SessionCookies) -> Void)?

    /// - Parameters:
    ///   - origin: scheme + host (+ port) of the instance, e.g.
    ///     `https://photos.example.com` or `http://localhost:3000`.
    ///   - cookies: a previously persisted session, if any.
    ///   - onCookiesChanged: called whenever the server rotates or
    ///     clears a cookie — the persistence hook.
    ///   - configuration: overridable for tests (URLProtocol stubs).
    public init(
        origin: String,
        cookies: SessionCookies = SessionCookies(),
        onCookiesChanged: (@Sendable (SessionCookies) -> Void)? = nil,
        configuration: URLSessionConfiguration = .ephemeral
    ) {
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

    public func get<T: Decodable & Sendable>(
        _ path: String,
        query: [URLQueryItem] = []
    ) async throws -> T {
        var request = URLRequest(url: url(path, query: query))
        request.httpMethod = "GET"
        return try await decode(send(request))
    }

    public func post<T: Decodable & Sendable, Body: Encodable & Sendable>(
        _ path: String,
        body: Body
    ) async throws -> T {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await decode(send(request))
    }

    /// Raw request for callers that need the response itself (the SSO
    /// consume reads its 302). Cookies are attached and captured; the
    /// refresh loop still applies.
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
        var request = URLRequest(url: url("/api/v1/tokens/refresh"))
        request.httpMethod = "POST"
        let (_, response) = try await perform(request)
        guard (200..<300).contains(response.statusCode) else {
            // The refresh handle itself was rejected — nothing left to
            // retry with. Drop both cookies so the next attempt doesn't
            // loop, and let the UI route to re-pairing.
            cookies = SessionCookies()
            onCookiesChanged?(cookies)
            throw InstanceError.sessionExpired
        }
    }

    private func capture(_ response: HTTPURLResponse, for url: URL) {
        let before = cookies
        cookies.apply(response: response, url: url)
        if cookies != before {
            onCookiesChanged?(cookies)
        }
    }

    private func decode<T: Decodable>(_ result: (Data, HTTPURLResponse)) throws -> T {
        let (data, response) = result
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 { throw InstanceError.sessionExpired }
            throw InstanceError.server(status: response.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw InstanceError.decoding(String(describing: error))
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
