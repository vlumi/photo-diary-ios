import Foundation

/// A photo gallery on a Photo Diary instance. Slim value type; extra
/// fields (theme, layout hints, per-view configuration) get added when
/// surfaces need them, not preemptively.
public struct Gallery: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let photoCount: Int

    public init(id: String, title: String, description: String = "", photoCount: Int) {
        self.id = id
        self.title = title
        self.description = description
        self.photoCount = photoCount
    }
}
