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
}

public enum InstanceError: Error, Sendable {
    case galleryNotFound(String)
    case photoNotFound(String)
    case notImplemented
}
