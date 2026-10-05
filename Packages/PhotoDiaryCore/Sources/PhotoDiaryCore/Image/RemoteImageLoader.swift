import Foundation
import Nuke

/// Photo bytes are public static files, so no session cookies are
/// involved and the default pipeline is enough.
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
