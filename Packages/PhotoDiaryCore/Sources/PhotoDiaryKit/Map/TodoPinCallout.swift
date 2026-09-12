import SwiftUI

/// Banner above a selected todo pin: the note (or a placeholder) and a
/// pencil to open the editor. Tapping elsewhere on the map deselects,
/// which closes it.
struct TodoPinCallout: View {
    let note: String
    let onEdit: () -> Void
    let onClose: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 10) {
            Text(note.isEmpty ? "No note yet" : note)
                .font(.subheadline)
                .foregroundStyle(note.isEmpty ? .secondary : .primary)
                .lineLimit(typeSize.isAccessibilitySize ? 5 : 2)
                .frame(maxWidth: 200, alignment: .leading)
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.body.weight(.semibold))
                    .padding(8)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit note")
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6, y: 2)
        .overlay(alignment: .topTrailing) { CalloutCloseButton(action: onClose) }
    }
}
