import Foundation

public struct SchemeRoutingImageLoader: ImageLoader {
    private let demo: DemoImageLoader
    private let remote: any ImageLoader

    public init(
        demo: DemoImageLoader = DemoImageLoader(),
        remote: any ImageLoader = RemoteImageLoader()
    ) {
        self.demo = demo
        self.remote = remote
    }

    public func loadImage(from url: URL) async throws -> PlatformImage {
        switch url.scheme {
        case "photodiary-demo":
            return try await demo.loadImage(from: url)
        case "https", "http":
            return try await remote.loadImage(from: url)
        default:
            throw ImageLoaderError.unsupportedScheme(url.scheme ?? "(none)")
        }
    }
}
