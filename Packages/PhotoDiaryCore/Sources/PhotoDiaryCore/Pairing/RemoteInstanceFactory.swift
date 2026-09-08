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

    /// Persisted ids predating origins were bare hosts; read them as https.
    public static func canonicalOrigin(_ id: String) -> String {
        id.contains("://") ? id : "https://" + id
    }

    public func makeAPI(origin: String, cookies: SessionCookies) -> PhotoDiaryAPI {
        let store = sessionStore
        return PhotoDiaryAPI(
            origin: origin,
            cookies: cookies,
            onCookiesChanged: { updated in
                // Persistence is best-effort here; a Keychain hiccup
                // shouldn't fail the request that rotated the cookie.
                try? store.save(updated, host: origin)
            },
            configuration: configuration()
        )
    }

    /// An instance paired in an earlier launch, with whatever session
    /// was persisted for it.
    public func restore(origin: String) -> RemoteInstance {
        let cookies = (try? sessionStore.load(host: origin)) ?? SessionCookies()
        return RemoteInstance(origin: origin, api: makeAPI(origin: origin, cookies: cookies))
    }

    public func make(origin: String, api: PhotoDiaryAPI) -> RemoteInstance {
        RemoteInstance(origin: origin, api: api)
    }
}
