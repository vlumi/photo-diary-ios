/// A nil gallery means every gallery the session can see.
public struct Scope: Codable, Hashable, Sendable {
    public let instanceId: String
    public let galleryId: String?

    public init(instanceId: String, galleryId: String? = nil) {
        self.instanceId = instanceId
        self.galleryId = galleryId
    }

    public var key: String { "\(instanceId)/\(galleryId ?? "*")" }
}
