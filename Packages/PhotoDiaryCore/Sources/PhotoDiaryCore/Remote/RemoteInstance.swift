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

    public init(host: String, api: PhotoDiaryAPI, lang: String? = nil) {
        self.id = host
        self.displayName = host
        self.api = api
        self.lang = lang ?? Locale.current.language.languageCode?.identifier ?? "en"
    }

    public func listGalleries() async throws -> [Gallery] {
        let dtos: [GalleryDTO] = try await api.get("/api/v1/galleries")
        return dtos.map { $0.toDomain() }
    }

    public func listPhotos(inGallery galleryId: String) async throws -> [Photo] {
        let root = try await resolvePhotoRoot()
        let dtos: [PhotoDTO] = try await api.post(
            "/api/v1/gallery-photos/\(galleryId)/query",
            body: PhotoQuery(lang: lang)
        )
        return
            dtos
            .map { $0.toDomain(galleryId: galleryId, photoRoot: root) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    public func getPhoto(id photoId: String, inGallery galleryId: String) async throws -> Photo {
        let root = try await resolvePhotoRoot()
        let dto: PhotoDTO = try await api.get(
            "/api/v1/gallery-photos/\(galleryId)/\(photoId)",
            query: [URLQueryItem(name: "lang", value: lang)]
        )
        return dto.toDomain(galleryId: galleryId, photoRoot: root)
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
