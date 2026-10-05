import Foundation

public struct Gallery: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    /// nil when the source doesn't report counts (the server's gallery
    /// list doesn't; the demo fixture does).
    public let photoCount: Int?

    public init(id: String, title: String, description: String = "", photoCount: Int? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.photoCount = photoCount
    }
}
