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

extension ImageLoaderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedScheme:
            String(localized: "This image isn't at an address the app can open.", bundle: .module)
        case .notFound:
            String(localized: "The image couldn't be downloaded.", bundle: .module)
        case .decodingFailed:
            String(localized: "The image couldn't be decoded.", bundle: .module)
        }
    }
}
