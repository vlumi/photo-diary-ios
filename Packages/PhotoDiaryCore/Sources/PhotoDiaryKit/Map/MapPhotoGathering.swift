/// The scope's photos across its galleries, from the cache (nil when
/// any part is missing) or the network. A photo linked into two
/// galleries arrives twice; one is kept.
enum MapPhotoGathering {
    static func photos(of scope: Scope, from instance: any Instance, cached: Bool) async throws
        -> [Photo]?
    {
        let galleryIds: [String]
        if let galleryId = scope.galleryId {
            galleryIds = [galleryId]
        } else if cached {
            guard let galleries = await instance.cachedGalleries() else { return nil }
            galleryIds = galleries.map(\.id)
        } else {
            galleryIds = try await instance.listGalleries().map(\.id)
        }
        var allPhotos: [Photo] = []
        for galleryId in galleryIds {
            if cached {
                guard let photos = await instance.cachedPhotos(inGallery: galleryId) else {
                    return nil
                }
                allPhotos.append(contentsOf: photos)
            } else {
                allPhotos.append(contentsOf: try await instance.listPhotos(inGallery: galleryId))
            }
        }
        // A photo linked into two galleries arrives twice; keep one.
        var seen = Set<String>()
        return allPhotos.filter { seen.insert($0.id).inserted }
    }
}
