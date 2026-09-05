#if canImport(SwiftData) && canImport(UIKit) && canImport(MapKit)
import MapKit
import SwiftData
import SwiftUI

/// Sheet listing every saved todo pin. Tap a row to centre the map
/// on that pin and open its editor; swipe-to-delete for cleanup.
struct TodoPinListSheet: View {
    let onDismiss: () -> Void
    let onSelect: (TodoPin) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \TodoPin.createdAt, order: .reverse) private var pins: [TodoPin]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Todo pins")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done", action: onDismiss)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if pins.isEmpty {
            ContentUnavailableView(
                "No todo pins yet",
                systemImage: "mappin.slash",
                description: Text("Drop one from the map's orange button.")
            )
        } else {
            List {
                ForEach(pins) { pin in
                    Button {
                        onSelect(pin)
                    } label: {
                        row(for: pin)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
            }
        }
    }

    private func row(for pin: TodoPin) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pin.note.isEmpty ? "(no note)" : pin.note)
                .font(.body)
                .foregroundStyle(pin.note.isEmpty ? .secondary : .primary)
                .lineLimit(2)
            Text(subtitle(for: pin))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func subtitle(for pin: TodoPin) -> String {
        let coord = String(format: "%.5f, %.5f", pin.latitude, pin.longitude)
        let date = pin.createdAt.formatted(date: .abbreviated, time: .shortened)
        return "\(coord)  ·  \(date)"
    }

    private func delete(_ offsets: IndexSet) {
        let store = TodoPinStore(context: context)
        for index in offsets {
            try? store.delete(pins[index])
        }
    }
}
#endif
