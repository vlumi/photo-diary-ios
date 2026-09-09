#if canImport(SwiftData) && canImport(UIKit) && canImport(MapKit)
import MapKit
import SwiftData
import SwiftUI

/// Sheet listing every saved todo pin, starred first, then by last edit
/// or by distance from the map's center (the toggle is remembered).
/// Tap a row to center the map on that pin; the star pins it to the
/// top; the pencil opens its editor; swipe-to-delete for cleanup.
struct TodoPinListSheet: View {
    enum Sort: String, CaseIterable {
        case recent = "Recent"
        case nearest = "Nearest"
    }

    let mapCenter: CLLocationCoordinate2D?
    let onDismiss: () -> Void
    let onSelect: (TodoPin) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: TodoPinStore.sortOrder) private var pins: [TodoPin]
    @State private var editing: TodoPin?
    @AppStorage("todoPinListSort") private var sort: Sort = .recent

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
        .sheet(item: $editing) { pin in
            TodoPinEditor(mode: .edit(pin)) { editing = nil }
        }
    }

    @ViewBuilder
    private var content: some View {
        if pins.isEmpty {
            ContentUnavailableView(
                "No todo pins yet",
                systemImage: "mappin.slash",
                description: Text("Long-press the map to drop one.")
            )
        } else {
            List {
                if mapCenter != nil {
                    Picker("Sort", selection: $sort) {
                        ForEach(Sort.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }
                ForEach(ordered) { pin in
                    HStack(spacing: 12) {
                        Button {
                            onSelect(pin)
                        } label: {
                            row(for: pin)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button {
                            try? TodoPinStore(context: context).setStarred(pin, !pin.isStarred)
                        } label: {
                            Image(systemName: pin.isStarred ? "star.fill" : "star")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.yellow)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(pin.isStarred ? "Unstar" : "Star")
                        Button {
                            editing = pin
                        } label: {
                            Image(systemName: "pencil")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit note")
                    }
                }
                .onDelete(perform: delete)
            }
        }
    }

    /// Starred pins stay on top in either mode; "nearest" reorders each
    /// group by distance from the map's center.
    private var ordered: [TodoPin] {
        guard sort == .nearest, let mapCenter else { return pins }
        let origin = CLLocation(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
        return pins.sorted { a, b in
            if a.isStarred != b.isStarred { return a.isStarred }
            return distance(of: a, from: origin) < distance(of: b, from: origin)
        }
    }

    private func distance(of pin: TodoPin, from origin: CLLocation) -> CLLocationDistance {
        CLLocation(latitude: pin.latitude, longitude: pin.longitude).distance(from: origin)
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
        let date = pin.updatedAt.formatted(date: .abbreviated, time: .shortened)
        guard let mapCenter else {
            return String(format: "%.5f, %.5f  ·  ", pin.latitude, pin.longitude) + date
        }
        let origin = CLLocation(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
        let meters = Measurement(value: distance(of: pin, from: origin), unit: UnitLength.meters)
        return meters.formatted(.measurement(width: .abbreviated, usage: .road)) + "  ·  " + date
    }

    private func delete(_ offsets: IndexSet) {
        let store = TodoPinStore(context: context)
        for index in offsets {
            try? store.delete(ordered[index])
        }
    }
}
#endif
