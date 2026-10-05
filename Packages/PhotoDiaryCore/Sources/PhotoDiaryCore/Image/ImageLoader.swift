import Foundation
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#else
import AppKit
public typealias PlatformImage = NSImage
#endif

/// Caching and retries are each loader's own business.
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
