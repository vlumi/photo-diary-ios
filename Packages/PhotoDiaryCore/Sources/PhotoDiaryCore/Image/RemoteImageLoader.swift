import Foundation
import Nuke

/// http(s) image loading through a Nuke pipeline: memory + disk cache,
/// in-flight request coalescing, cancellation on task cancel. Photo
/// bytes are served by nginx as public static files, so no session
/// cookies are involved — the default pipeline is enough.
public final class RemoteImageLoader: ImageLoader {
    private let pipeline: ImagePipeline

    public init(pipeline: ImagePipeline = ImagePipeline(configuration: .withDataCache)) {
        self.pipeline = pipeline
    }

    public func loadImage(from url: URL) async throws -> PhotoDiaryCore.PlatformImage {
        guard url.scheme == "https" || url.scheme == "http" else {
            throw ImageLoaderError.unsupportedScheme(url.scheme ?? "(none)")
        }
        do {
            return try await pipeline.image(for: url)
        } catch {
            throw ImageLoaderError.notFound(url)
        }
    }
}
