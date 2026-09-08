import Foundation

/// A real photo-diary server. Read-only, cookie-authenticated via
/// PhotoDiaryAPI. The id is the host, which is also what the Keychain
/// entry is keyed by.
///
/// The photo root (where display/thumbnail bytes live) comes from the
/// instance's `meta.cdn` when set and the API host otherwise — the
/// same rule the SPA applies. Resolved once on first use.
public actor RemoteInstance: Instance {
    public nonisolated let id: String
    public nonisolated let displayName: String
    public nonisolated let isDemo = false

    private let api: PhotoDiaryAPI
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
        host: String,
        api: PhotoDiaryAPI,
        lang: String? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.id = host
        self.displayName = host
        self.api = api
        self.lang = lang ?? Locale.current.language.languageCode?.identifier ?? "en"
        self.now = now
    }

    public func listGalleries() async throws -> [Gallery] {
        let dtos: [GalleryDTO] = try await api.get("/api/v1/galleries")
        return dtos.map { $0.toDomain() }
    }

    public func listPhotos(inGallery galleryId: String) async throws -> [Photo] {
        if let cached = freshCache(for: galleryId) { return cached }
        let root = try await resolvePhotoRoot()
        let dtos: [PhotoDTO] = try await api.post(
            "/api/v1/gallery-photos/\(galleryId)/query",
            body: PhotoQuery(lang: lang)
        )
        let photos =
            dtos
            .map { $0.toDomain(galleryId: galleryId, photoRoot: root) }
            .sorted { $0.timestamp < $1.timestamp }
        photoCache[galleryId] = CachedPhotos(photos: photos, fetchedAt: now())
        return photos
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
        let meta: MetaDTO = try await api.get("/api/v1/meta")
        let root: URL
        if let cdn = meta.cdn, let url = URL(string: cdn.hasSuffix("/") ? cdn : cdn + "/") {
            root = url
        } else {
            root = api.baseURL
        }
        photoRoot = root
        return root
    }
}

private struct PhotoQuery: Encodable {
    let lang: String
}
