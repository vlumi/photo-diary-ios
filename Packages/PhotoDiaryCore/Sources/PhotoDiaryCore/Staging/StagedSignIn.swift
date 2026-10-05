#if DEBUG
import Foundation

extension LaunchStage.SignIn {
    /// The session a password sign-in hands out. The app itself only
    /// pairs; this is for staged launches, which have no one to pair.
    public func cookies(using session: URLSession = .shared) async throws -> SessionCookies {
        let url = URL(string: origin)!.appending(path: "api/v1/tokens")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["id": user, "password": password])
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let http = response as? HTTPURLResponse else {
            throw InstanceError.server(status: status)
        }
        var cookies = SessionCookies()
        cookies.apply(response: http, url: url)
        return cookies
    }
}
#endif
