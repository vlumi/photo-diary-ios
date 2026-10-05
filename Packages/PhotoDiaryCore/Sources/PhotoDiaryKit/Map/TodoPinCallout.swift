import SwiftUI

struct TodoPinCallout: View {
    let note: String
    let photo: Data?
    let onOpenPhoto: () -> Void
    let onEdit: () -> Void
    let onClose: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 10) {
            #if canImport(UIKit)
            if let photo {
                Button(action: onOpenPhoto) {
                    TodoPinPhotoImage(data: photo)
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows the photo full screen.")
            }
            #endif
            (note.isEmpty ? Text("No note yet") : Text(verbatim: note))
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
