#if canImport(SwiftData)
import Foundation
import SwiftData

/// Convenience wrapper around SwiftData's ModelContext for TodoPin
/// CRUD. Kept small on purpose — views can read pins directly with
/// @Query where reactivity matters and use this only for write paths
/// where the imperative shape is clearer.
@MainActor
public struct TodoPinStore {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Persist a new pin at the given coordinate. Returns the saved
    /// entity so the caller can immediately show it in the UI.
    @discardableResult
    public func create(latitude: Double, longitude: Double, note: String = "") throws -> TodoPin {
        let pin = TodoPin(latitude: latitude, longitude: longitude, note: note)
        context.insert(pin)
        try context.save()
        return pin
    }

    /// Update a pin's note (the only mutable field on the current
    /// shape). Bumps updatedAt.
    public func updateNote(_ pin: TodoPin, note: String) throws {
        pin.note = note
        pin.updatedAt = .now
        try context.save()
    }

    public func delete(_ pin: TodoPin) throws {
        context.delete(pin)
        try context.save()
    }

    /// Fetch every pin, newest first. Views that want reactivity
    /// should use @Query instead; this exists for one-off reads.
    public func all() throws -> [TodoPin] {
        try context.fetch(
            FetchDescriptor<TodoPin>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
    }
}
#endif
