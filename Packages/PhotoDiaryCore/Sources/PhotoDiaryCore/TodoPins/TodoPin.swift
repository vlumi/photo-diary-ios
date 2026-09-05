#if canImport(SwiftData)
import Foundation
import SwiftData

/// A user-authored location note. Local-only: never leaves the
/// device, never syncs to a Photo Diary instance. Stored via
/// SwiftData so the shape can grow (attachments, reminders) without
/// hand-rolling migrations.
///
/// Coordinates are stored as raw Double pairs rather than
/// CLLocationCoordinate2D so the schema is portable and inspectable
/// with any SQLite tool if we ever need to.
@Model
public final class TodoPin {
    /// Stable identifier — generated on creation, immutable.
    @Attribute(.unique) public var id: UUID
    public var latitude: Double
    public var longitude: Double
    public var note: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
#endif
