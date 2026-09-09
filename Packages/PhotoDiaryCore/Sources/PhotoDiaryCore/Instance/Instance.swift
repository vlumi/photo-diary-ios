import Foundation

/// The single data-access boundary every UI surface sits above. Two
/// concrete implementations plan to live behind it:
///
/// - `DemoInstance` — bundled fixture data, no network. Ships in v1
///   for App Store review credentials, screenshots, and offline dev.
/// - `RemoteInstance` — talks to a real Photo Diary server via
///   /api/v1/*. Auth cookies keyed per host in the Keychain.
///
/// Async, throws on failure. All methods are read-only — this app
/// never writes to the server.
public protocol Instance: Sendable {
    /// Stable id used to key credentials + preferences per instance.
    /// Hostname for remote instances; a fixed sentinel for the demo
    /// instance.
    var id: String { get }

    /// User-facing name for the instance list.
    var displayName: String { get }

    /// True when this instance renders fixture data instead of talking
    /// to a server. Consumers use it to hide auth-only chrome (e.g.
    /// the "signed in as ..." Settings row) in demo mode.
    var isDemo: Bool { get }

    /// All galleries visible to the current session on this instance.
    func listGalleries() async throws -> [Gallery]

    /// All photos in the given gallery. Ordering: EXIF timestamp
    /// ascending — the same order the site's calendar views use.
    func listPhotos(inGallery galleryId: String) async throws -> [Photo]

    /// A single photo by id. Used when navigating directly (e.g. a
    /// map-pin popup) without loading the whole gallery.
    func getPhoto(id: String, inGallery galleryId: String) async throws -> Photo

    /// The last answers this instance gave, without touching the
    /// network — what a screen shows while the fresh one loads. nil
    /// when nothing is cached.
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
    case notImplemented
    /// The refresh token was rejected; the user must pair again.
    case sessionExpired
    /// Non-2xx from the server that isn't a session problem.
    case server(status: Int)
    /// Network-level failure (offline, DNS, TLS).
    case transport(String)
    /// The response didn't match the wire shape we expect.
    case decoding(String)
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
        case .notImplemented:
            String(localized: "This isn't supported by the app yet.", bundle: .module)
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
