/// What the Map and Calendar are showing: an instance, and optionally
/// one of its galleries. nil gallery means every gallery the session
/// can see. Chosen on the front page, restored on the next launch.
public struct Scope: Codable, Hashable, Sendable {
    public let instanceId: String
    public let galleryId: String?

    public init(instanceId: String, galleryId: String? = nil) {
        self.instanceId = instanceId
        self.galleryId = galleryId
    }

    /// One string per scope, for keying per-scope state.
    public var key: String { "\(instanceId)/\(galleryId ?? "*")" }
}
