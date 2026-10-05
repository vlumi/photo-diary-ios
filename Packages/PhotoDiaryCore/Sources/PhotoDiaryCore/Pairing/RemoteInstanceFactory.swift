import Foundation

/// Cookie changes flow into the SessionStore, so an instance knows
/// nothing about persistence.
public struct RemoteInstanceFactory: Sendable {
    private let sessionStore: any SessionStore
    /// Where instances keep their last answers; nil in tests.
    public let cache: ResponseCache?
    /// URLSessionConfiguration isn't Sendable; a factory closure lets
    /// tests inject a stubbed protocol per API instance.
    private let configuration: @Sendable () -> URLSessionConfiguration

    public init(
        sessionStore: any SessionStore,
        cache: ResponseCache? = nil,
        configuration: @escaping @Sendable () -> URLSessionConfiguration = { .ephemeral }
    ) {
        self.sessionStore = sessionStore
        self.cache = cache
        self.configuration = configuration
    }

    /// Persisted ids predating origins were bare hosts; read them as https.
    public static func canonicalOrigin(_ id: String) -> String {
        id.contains("://") ? id : "https://" + id
    }

    public func makeAPI(
        origin: String, cookies: SessionCookies, persisting: Bool = true
    ) -> PhotoDiaryAPI {
        let store = sessionStore
        return PhotoDiaryAPI(
            origin: origin,
            cookies: cookies,
            onCookiesChanged: { updated in
                // Persistence is best-effort here; a Keychain hiccup
                // shouldn't fail the request that rotated the cookie.
                try? store.save(updated, host: origin)
            },
            persisting: persisting,
            configuration: configuration()
        )
    }

    public func restore(origin: String) -> RemoteInstance {
        let cookies = (try? sessionStore.load(host: origin)) ?? SessionCookies()
        return RemoteInstance(
            origin: origin, api: makeAPI(origin: origin, cookies: cookies), cache: cache)
    }

    public func make(origin: String, api: PhotoDiaryAPI) -> RemoteInstance {
        RemoteInstance(origin: origin, api: api, cache: cache)
    }
}
