#if canImport(SwiftData) && canImport(UIKit) && canImport(MapKit)
import MapKit
import SwiftData
import SwiftUI

struct TodoPinListSheet: View {
    enum Sort: String, CaseIterable {
        // Raw values are what the user's choice is stored under.
        case recent = "Recent"
        case nearest = "Nearest"

        var label: String {
            switch self {
            case .recent: String(localized: "Recent")
            case .nearest: String(localized: "Nearest")
            }
        }
    }

    let mapCenter: CLLocationCoordinate2D?
    let onDismiss: () -> Void
    let onSelect: (TodoPin) -> Void
    /// A new pin where the map is centered: the way to add one without
    /// a long-press, for VoiceOver among others.
    let onAddAtCenter: () -> Void

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
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add pin at map center", systemImage: "plus", action: onAddAtCenter)
                            .disabled(mapCenter == nil)
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
            ContentUnavailableView {
                Label("No todo pins yet", systemImage: "mappin.slash")
            } description: {
                Text("Touch and hold the map to drop one, or add one where the map is centered.")
            } actions: {
                Button("Add pin at map center", action: onAddAtCenter)
                    .buttonStyle(.borderedProminent)
                    .disabled(mapCenter == nil)
            }
        } else {
            List {
                if mapCenter != nil {
                    Picker("Sort", selection: $sort) {
                        ForEach(Sort.allCases, id: \.self) { Text($0.label) }
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
                        .accessibilityHint("Shows it on the map.")
                        Button {
                            try? TodoPinStore(context: context).setStarred(pin, !pin.isStarred)
                        } label: {
                            Image(systemName: pin.isStarred ? "star.fill" : "star")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.yellow)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(pin.isStarred ? "Unstar" : "Star")
                        .sensoryFeedback(.selection, trigger: pin.isStarred)
                        Button {
                            editing = pin
                        } label: {
                            Image(systemName: "pencil")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.orange)
                                .frame(minWidth: 44, minHeight: 44)
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

    private var ordered: [TodoPin] {
        guard sort == .nearest, let mapCenter else { return pins }
        return TodoPinStore.nearestFirst(pins, to: mapCenter)
    }

    private func row(for pin: TodoPin) -> some View {
        HStack(spacing: 10) {
            if let photo = pin.photo {
                TodoPinPhotoImage(data: photo)
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            rowText(for: pin)
        }
    }

    private func rowText(for pin: TodoPin) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            (pin.note.isEmpty ? Text("No note yet") : Text(verbatim: pin.note))
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
        let meters = Measurement(
            value: TodoPinStore.distance(of: pin, from: mapCenter), unit: UnitLength.meters)
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
