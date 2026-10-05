#if canImport(SwiftData)
import SwiftData
import SwiftUI

extension ModelContext {
    /// A todo-pin write. A failure is rolled back, so the screen shows
    /// what's stored, and comes back as the message to say so.
    @MainActor
    func pinWrite(_ write: (TodoPinStore) throws -> Void) -> String? {
        do {
            try write(TodoPinStore(context: self))
            return nil
        } catch {
            rollback()
            return error.localizedDescription
        }
    }
}

extension View {
    func pinWriteFailureAlert(_ failure: Binding<String?>) -> some View {
        alert(
            "Couldn't save the pin",
            isPresented: Binding(
                get: { failure.wrappedValue != nil }, set: { if !$0 { failure.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure.wrappedValue ?? "")
        }
    }
}
#endif
