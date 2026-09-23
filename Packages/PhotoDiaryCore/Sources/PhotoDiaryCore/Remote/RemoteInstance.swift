import Foundation

/// A real photo-diary server. Read-only, cookie-authenticated via
/// PhotoDiaryAPI. The id is the origin (scheme://host[:port]), which
/// is also what the Keychain entry is keyed by. The display name
/// drops a plain `https://` but keeps `http://…` visible, so an
/// unencrypted local instance always looks like one.
///
/// The photo root (where display/thumbnail bytes live) comes from the
/// instance's `meta.cdn` when set and the API host otherwise — the
/// same rule the SPA applies. Resolved once on first use.
public actor RemoteInstance: Instance {
    public nonisolated let id: String
    public nonisolated let displayName: String
    public nonisolated let isDemo = false

    private let api: PhotoDiaryAPI
    private let client: PhotoDiaryClient
    private let cache: ResponseCache?
    private var photoRoot: URL?
    /// Sent with photo queries so the server picks localized titles.
    private let lang: String
    private let now: @Sendable () -> Date

    /// The calendar drill-down asks for a gallery's photos at every
    /// level and the map asks for every gallery; a real gallery is a
    /// multi-MB JSON, so repeats are served from memory. Short TTL so
    /// photos added on the site appear on the next navigation without
    /// an explicit refresh.
    public static let photoCacheTTL: TimeInterval = 5 * 60
    private struct CachedPhotos {
        let photos: [Photo]
        let fetchedAt: Date
    }
    private var photoCache: [String: CachedPhotos] = [:]

    public init(
        origin: String,
        api: PhotoDiaryAPI,
        cache: ResponseCache? = nil,
        lang: String? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.id = origin
        self.displayName =
            origin.hasPrefix("https://") ? String(origin.dropFirst("https://".count)) : origin
        self.api = api
        self.client = PhotoDiaryClient(api: api)
        self.cache = cache
        self.lang = lang ?? Locale.current.language.languageCode?.identifier ?? "en"
        self.now = now
    }

    public func listGalleries() async throws -> [Gallery] {
        let galleries = try await client.call { client in
            switch try await client.listGalleries() {
            case .ok(let ok): return try ok.body.json
            case .unauthorized: throw InstanceError.sessionExpired
            case .forbidden: throw InstanceError.server(status: 403)
            case .undocumented(let status, _): throw unexpected(status: status)
            }
        }
        cache?.save(Self.encoded(galleries), origin: id, key: "galleries")
        return galleries.map { $0.toDomain() }
    }

    public func listPhotos(inGallery galleryId: String) async throws -> [Photo] {
        if let cached = freshCache(for: galleryId) { return cached }
        let root = try await resolvePhotoRoot()
        let lang = lang
        let wire = try await client.call { client in
            switch try await client.queryGalleryPhotos(
                path: .init(galleryId: galleryId), body: .json(.init(lang: lang)))
            {
            case .ok(let ok): return try ok.body.json
            case .notFound: throw InstanceError.galleryNotFound(galleryId)
            case .unauthorized: throw InstanceError.sessionExpired
            case .forbidden: throw InstanceError.server(status: 403)
            case .undocumented(let status, _): throw unexpected(status: status)
            }
        }
        cache?.save(Self.encoded(wire), origin: id, key: "photos/" + galleryId)
        let photos = Self.photos(from: wire, galleryId: galleryId, photoRoot: root)
        photoCache[galleryId] = CachedPhotos(photos: photos, fetchedAt: now())
        return photos
    }

    public func cachedGalleries() async -> [Gallery]? {
        let wire: [Components.Schemas.Gallery]? = cached("galleries")
        return wire?.map { $0.toDomain() }
    }

    /// Needs the photo root too: resolved already, or the cached meta.
    public func cachedPhotos(inGallery galleryId: String) async -> [Photo]? {
        guard let wire: [Components.Schemas.Photo] = cached("photos/" + galleryId),
            let root = photoRoot ?? cachedPhotoRoot()
        else { return nil }
        return Self.photos(from: wire, galleryId: galleryId, photoRoot: root)
    }

    private static func photos(
        from wire: [Components.Schemas.Photo], galleryId: String, photoRoot: URL
    ) -> [Photo] {
        wire
            .compactMap { $0.toDomain(galleryId: galleryId, photoRoot: photoRoot) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    public func getPhoto(id photoId: String, inGallery galleryId: String) async throws -> Photo {
        if let hit = freshCache(for: galleryId)?.first(where: { $0.id == photoId }) {
            return hit
        }
        let root = try await resolvePhotoRoot()
        let lang = lang
        let wire = try await client.call { client in
            switch try await client.getGalleryPhoto(
                path: .init(galleryId: galleryId, photoId: photoId), query: .init(lang: lang))
            {
            case .ok(let ok): return try ok.body.json
            case .notFound: throw InstanceError.photoNotFound(photoId)
            case .unauthorized: throw InstanceError.sessionExpired
            case .forbidden: throw InstanceError.server(status: 403)
            case .undocumented(let status, _): throw unexpected(status: status)
            }
        }
        guard let photo = wire.toDomain(galleryId: galleryId, photoRoot: root) else {
            throw InstanceError.photoNotFound(photoId)
        }
        return photo
    }

    private func freshCache(for galleryId: String) -> [Photo]? {
        guard let entry = photoCache[galleryId],
            now().timeIntervalSince(entry.fetchedAt) < Self.photoCacheTTL
        else { return nil }
        return entry.photos
    }

    private func resolvePhotoRoot() async throws -> URL {
        if let photoRoot { return photoRoot }
        let meta = try await client.call { client in
            switch try await client.getMeta() {
            case .ok(let ok): return try ok.body.json
            case .undocumented(let status, _): throw unexpected(status: status)
            }
        }
        cache?.save(Self.encoded(meta), origin: id, key: "meta")
        let root = Self.photoRoot(from: meta, apiBase: api.baseURL)
        photoRoot = root
        return root
    }

    private func cachedPhotoRoot() -> URL? {
        let meta: Operations.GetMeta.Output.Ok.Body.JsonPayload? = cached("meta")
        return meta.map { Self.photoRoot(from: $0, apiBase: api.baseURL) }
    }

    private static func photoRoot(
        from meta: Operations.GetMeta.Output.Ok.Body.JsonPayload, apiBase: URL
    ) -> URL {
        if let cdn = meta.cdn, let url = URL(string: cdn.hasSuffix("/") ? cdn : cdn + "/") {
            return url
        }
        return apiBase
    }

    // The disk cache keeps each answer as the JSON the server sent, so
    // an entry written before the generated client reads the same way.
    private static func encoded<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private func cached<T: Decodable>(_ key: String) -> T? {
        guard let data = cache?.load(origin: id, key: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
