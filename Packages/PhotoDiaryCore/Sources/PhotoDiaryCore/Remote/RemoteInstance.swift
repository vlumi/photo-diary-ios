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
        self.cache = cache
        self.lang = lang ?? Locale.current.language.languageCode?.identifier ?? "en"
        self.now = now
    }

    public func listGalleries() async throws -> [Gallery] {
        let data = try await api.fetch("/api/v1/galleries")
        let galleries = try Self.galleries(from: data)
        cache?.save(data, origin: id, key: "galleries")
        return galleries
    }

    public func listPhotos(inGallery galleryId: String) async throws -> [Photo] {
        if let cached = freshCache(for: galleryId) { return cached }
        let root = try await resolvePhotoRoot()
        let data = try await api.fetch(
            "/api/v1/gallery-photos/\(galleryId)/query", body: PhotoQuery(lang: lang))
        let photos = try Self.photos(from: data, galleryId: galleryId, photoRoot: root)
        cache?.save(data, origin: id, key: "photos/" + galleryId)
        photoCache[galleryId] = CachedPhotos(photos: photos, fetchedAt: now())
        return photos
    }

    public func cachedGalleries() async -> [Gallery]? {
        guard let data = cache?.load(origin: id, key: "galleries") else { return nil }
        return try? Self.galleries(from: data)
    }

    /// Needs the photo root too: resolved already, or the cached meta.
    public func cachedPhotos(inGallery galleryId: String) async -> [Photo]? {
        guard let data = cache?.load(origin: id, key: "photos/" + galleryId),
            let root = photoRoot ?? cachedPhotoRoot()
        else { return nil }
        return try? Self.photos(from: data, galleryId: galleryId, photoRoot: root)
    }

    private static func galleries(from data: Data) throws -> [Gallery] {
        let dtos: [GalleryDTO] = try PhotoDiaryAPI.decode(data)
        return dtos.map { $0.toDomain() }
    }

    private static func photos(from data: Data, galleryId: String, photoRoot: URL) throws
        -> [Photo]
    {
        let dtos: [PhotoDTO] = try PhotoDiaryAPI.decode(data)
        return
            dtos
            .map { $0.toDomain(galleryId: galleryId, photoRoot: photoRoot) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    public func getPhoto(id photoId: String, inGallery galleryId: String) async throws -> Photo {
        if let hit = freshCache(for: galleryId)?.first(where: { $0.id == photoId }) {
            return hit
        }
        let root = try await resolvePhotoRoot()
        let dto: PhotoDTO = try await api.get(
            "/api/v1/gallery-photos/\(galleryId)/\(photoId)",
            query: [URLQueryItem(name: "lang", value: lang)]
        )
        return dto.toDomain(galleryId: galleryId, photoRoot: root)
    }

    private func freshCache(for galleryId: String) -> [Photo]? {
        guard let entry = photoCache[galleryId],
            now().timeIntervalSince(entry.fetchedAt) < Self.photoCacheTTL
        else { return nil }
        return entry.photos
    }

    private func resolvePhotoRoot() async throws -> URL {
        if let photoRoot { return photoRoot }
        let data = try await api.fetch("/api/v1/meta")
        let root = try Self.photoRoot(from: data, apiBase: api.baseURL)
        cache?.save(data, origin: id, key: "meta")
        photoRoot = root
        return root
    }

    private func cachedPhotoRoot() -> URL? {
        guard let data = cache?.load(origin: id, key: "meta") else { return nil }
        return try? Self.photoRoot(from: data, apiBase: api.baseURL)
    }

    private static func photoRoot(from data: Data, apiBase: URL) throws -> URL {
        let meta: MetaDTO = try PhotoDiaryAPI.decode(data)
        if let cdn = meta.cdn, let url = URL(string: cdn.hasSuffix("/") ? cdn : cdn + "/") {
            return url
        }
        return apiBase
    }
}

private struct PhotoQuery: Encodable {
    let lang: String
}
