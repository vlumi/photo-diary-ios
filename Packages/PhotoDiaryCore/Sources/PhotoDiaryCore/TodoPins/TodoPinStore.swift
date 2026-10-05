#if canImport(SwiftData)
import Foundation
import SwiftData

@MainActor
public struct TodoPinStore {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func create(
        latitude: Double, longitude: Double, note: String = "", photo: Data? = nil
    ) throws -> TodoPin {
        let pin = TodoPin(latitude: latitude, longitude: longitude, note: note, photo: photo)
        context.insert(pin)
        try context.save()
        return pin
    }

    public func updateNote(_ pin: TodoPin, note: String) throws {
        pin.note = note
        pin.updatedAt = .now
        try context.save()
    }

    public func setPhoto(_ pin: TodoPin, _ photo: Data?) throws {
        pin.photo = photo
        pin.updatedAt = .now
        try context.save()
    }

    public func delete(_ pin: TodoPin) throws {
        context.delete(pin)
        try context.save()
    }

    public func move(_ pin: TodoPin, latitude: Double, longitude: Double) throws {
        pin.latitude = latitude
        pin.longitude = longitude
        pin.updatedAt = .now
        try context.save()
    }

    /// Starring does not count as an edit, so it leaves updatedAt alone.
    public func setStarred(_ pin: TodoPin, _ starred: Bool) throws {
        pin.starredAt = starred ? .now : nil
        try context.save()
    }

    /// Nil sorts last when descending, so starred pins come first.
    public static let sortOrder: [SortDescriptor<TodoPin>] = [
        SortDescriptor(\.starredAt, order: .reverse),
        SortDescriptor(\.updatedAt, order: .reverse),
    ]

    public func all() throws -> [TodoPin] {
        try context.fetch(FetchDescriptor<TodoPin>(sortBy: Self.sortOrder))
    }
}
#endif
