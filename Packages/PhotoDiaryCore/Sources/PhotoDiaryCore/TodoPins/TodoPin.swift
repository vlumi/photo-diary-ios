#if canImport(SwiftData)
import Foundation
import SwiftData

/// Local-only: never leaves the device.
@Model
public final class TodoPin {
    @Attribute(.unique) public var id: UUID
    public var latitude: Double
    public var longitude: Double
    public var note: String
    /// A date rather than a Bool because SwiftData can only sort on
    /// Comparable attributes.
    public var starredAt: Date?
    /// Kept outside the database row so listing pins doesn't read every
    /// image.
    @Attribute(.externalStorage) public var photo: Data?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        note: String = "",
        starredAt: Date? = nil,
        photo: Data? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.starredAt = starredAt
        self.photo = photo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isStarred: Bool { starredAt != nil }
}
#endif
