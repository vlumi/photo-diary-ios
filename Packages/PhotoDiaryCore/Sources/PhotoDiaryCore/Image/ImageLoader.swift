import Foundation
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#else
import AppKit
public typealias PlatformImage = NSImage
#endif

/// The single image-fetching seam. One implementation per URL scheme
/// family — DemoImageLoader for `photodiary-demo://`, a future
/// RemoteImageLoader for `https://` on real instances.
///
/// Loaders return decoded platform images. Caching, retries, and
/// disk staging are each loader's problem — the caller just awaits.
public protocol ImageLoader: Sendable {
    func loadImage(from url: URL) async throws -> PlatformImage
}

public enum ImageLoaderError: Error, Sendable {
    case unsupportedScheme(String)
    case notFound(URL)
    case decodingFailed(URL)
}
