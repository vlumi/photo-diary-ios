import Foundation

/// Read-only: the app never writes to the server.
public protocol Instance: Sendable {
    /// Keys sessions and saved state: the origin for a remote instance,
    /// a sentinel for the demo.
    var id: String { get }

    var displayName: String { get }

    /// The demo has no site to link to and is labeled apart on the
    /// front page.
    var isDemo: Bool { get }

    func listGalleries() async throws -> [Gallery]

    /// Ascending by capture time, as on the site.
    func listPhotos(inGallery galleryId: String) async throws -> [Photo]

    func getPhoto(id: String, inGallery galleryId: String) async throws -> Photo

    /// What a screen shows while the fresh answer loads; nil when
    /// nothing is cached.
    func cachedGalleries() async -> [Gallery]?
    func cachedPhotos(inGallery galleryId: String) async -> [Photo]?
}

extension Instance {
    public func cachedGalleries() async -> [Gallery]? { nil }
    public func cachedPhotos(inGallery galleryId: String) async -> [Photo]? { nil }
}

public enum InstanceError: Error, Sendable {
    case galleryNotFound(String)
    case photoNotFound(String)
    case sessionExpired
    case server(status: Int)
    case transport(String)
    case decoding(String)
}

extension InstanceError {
    /// Unlike a network blip or a server hiccup, after which what's
    /// cached still stands.
    public var deniesAccess: Bool {
        switch self {
        case .sessionExpired, .galleryNotFound: true
        case .server(let status): status == 403 || status == 404
        default: false
        }
    }
}

// Without this, SwiftUI shows "The operation couldn't be completed
// (InstanceError error 5)" wherever a load fails.
extension InstanceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .galleryNotFound:
            String(localized: "This gallery no longer exists on the server.", bundle: .module)
        case .photoNotFound:
            String(localized: "This photo no longer exists on the server.", bundle: .module)
        case .sessionExpired:
            String(localized: "Your session has expired. Pair this device again.", bundle: .module)
        case .server(let status):
            String(localized: "The server returned an error (HTTP \(status)).", bundle: .module)
        case .transport(let detail):
            String(localized: "Couldn't reach the server. \(detail)", bundle: .module)
        case .decoding:
            String(localized: "The server sent a response the app couldn't read.", bundle: .module)
        }
    }
}
