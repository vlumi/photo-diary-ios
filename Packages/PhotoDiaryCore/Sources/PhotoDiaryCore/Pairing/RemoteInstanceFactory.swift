import Foundation

/// Builds RemoteInstances whose cookie changes flow into the
/// SessionStore, so a session survives relaunch without the instance
/// knowing anything about persistence.
public struct RemoteInstanceFactory: Sendable {
    private let sessionStore: any SessionStore
    /// URLSessionConfiguration isn't Sendable; a factory closure lets
    /// tests inject a stubbed protocol per API instance.
    private let configuration: @Sendable () -> URLSessionConfiguration

    public init(
        sessionStore: any SessionStore,
        configuration: @escaping @Sendable () -> URLSessionConfiguration = { .ephemeral }
    ) {
        self.sessionStore = sessionStore
        self.configuration = configuration
    }

    public func makeAPI(host: String, cookies: SessionCookies) -> PhotoDiaryAPI {
        let store = sessionStore
        return PhotoDiaryAPI(
            host: host,
            cookies: cookies,
            onCookiesChanged: { updated in
                // Persistence is best-effort here; a Keychain hiccup
                // shouldn't fail the request that rotated the cookie.
                try? store.save(updated, host: host)
            },
            configuration: configuration()
        )
    }

    /// An instance for a host paired in an earlier launch, with
    /// whatever session was persisted for it.
    public func restore(host: String) -> RemoteInstance {
        let cookies = (try? sessionStore.load(host: host)) ?? SessionCookies()
        return RemoteInstance(host: host, api: makeAPI(host: host, cookies: cookies))
    }

    public func make(host: String, api: PhotoDiaryAPI) -> RemoteInstance {
        RemoteInstance(host: host, api: api)
    }
}
