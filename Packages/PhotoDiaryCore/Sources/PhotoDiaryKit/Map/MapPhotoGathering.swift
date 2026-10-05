/// Cached, nil when any gallery is missing. A photo linked into two
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
        let skipsMissing = scope.galleryId == nil
        let perGallery = try await withThrowingTaskGroup(of: (Int, [Photo]?).self) { group in
            for (index, galleryId) in galleryIds.enumerated() {
                group.addTask {
                    (
                        index,
                        try await photos(
                            of: galleryId, from: instance, cached: cached,
                            skippingMissing: skipsMissing)
                    )
                }
            }
            var results = [[Photo]?](repeating: nil, count: galleryIds.count)
            for try await (index, photos) in group { results[index] = photos }
            return results
        }
        if cached, perGallery.contains(where: { $0 == nil }) { return nil }
        var seen = Set<String>()
        return perGallery.flatMap { $0 ?? [] }.filter { seen.insert($0.id).inserted }
    }

    private static func photos(
        of galleryId: String, from instance: any Instance, cached: Bool, skippingMissing: Bool
    ) async throws -> [Photo]? {
        if cached { return await instance.cachedPhotos(inGallery: galleryId) }
        do {
            return try await instance.listPhotos(inGallery: galleryId)
        } catch InstanceError.galleryNotFound where skippingMissing {
            // One of an instance's galleries went away, or out of reach,
            // since they were listed. That costs its photos, not the map:
            // only losing the gallery the scope is about sends the user back.
            return []
        }
    }
}
