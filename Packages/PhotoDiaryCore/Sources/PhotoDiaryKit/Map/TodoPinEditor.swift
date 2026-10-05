#if canImport(SwiftData) && canImport(UIKit)
import SwiftData
import SwiftUI

/// Sheet for editing a todo pin's note and photo. Create-mode drops a
/// new pin; edit-mode edits an existing one. Delete only appears in
/// edit mode. A new or removed photo waits for Save like the note.
struct TodoPinEditor: View {
    enum Mode {
        case create(latitude: Double, longitude: Double)
        case edit(TodoPin)
    }

    let mode: Mode
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var context
    @State private var note: String = ""
    @State private var photo: Data?
    @State private var showingCamera = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("What's here?", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($noteFocused)
                }
                photoSection
                Section {
                    Text(coordinateLabel)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                }
                if case .edit(let pin) = mode {
                    Section {
                        Button("Delete pin", role: .destructive) {
                            deleteAndDismiss(pin)
                        }
                    }
                }
            }
            .navigationTitle(titleForMode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                }
            }
            .onAppear {
                if case .edit(let pin) = mode {
                    note = pin.note
                    photo = pin.photo
                }
                noteFocused = true
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker(
                    onCapture: { image in
                        photo = TodoPinPhoto.jpeg(from: image) ?? photo
                        showingCamera = false
                    },
                    onCancel: { showingCamera = false }
                )
                .ignoresSafeArea()
            }
        }
    }

    // Without a camera (the simulator) and no photo yet, there's
    // nothing to show or do here.
    @ViewBuilder
    private var photoSection: some View {
        if photo != nil || CameraPicker.isAvailable {
            Section("Photo") {
                if let photo {
                    TodoPinPhotoImage(data: photo)
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if CameraPicker.isAvailable {
                    Button(photo == nil ? "Take photo" : "Retake photo", systemImage: "camera") {
                        noteFocused = false
                        showingCamera = true
                    }
                }
                if photo != nil {
                    Button("Remove photo", systemImage: "trash", role: .destructive) {
                        photo = nil
                    }
                }
            }
        }
    }

    private var titleForMode: String {
        switch mode {
        case .create: return String(localized: "New pin")
        case .edit: return String(localized: "Edit pin")
        }
    }

    private var coordinateLabel: String {
        switch mode {
        case .create(let lat, let lng):
            return String(format: "%.5f, %.5f", lat, lng)
        case .edit(let pin):
            return String(format: "%.5f, %.5f", pin.latitude, pin.longitude)
        }
    }

    private func saveAndDismiss() {
        let store = TodoPinStore(context: context)
        do {
            switch mode {
            case .create(let lat, let lng):
                try store.create(latitude: lat, longitude: lng, note: note, photo: photo)
            case .edit(let pin):
                try store.updateNote(pin, note: note)
                if photo != pin.photo { try store.setPhoto(pin, photo) }
            }
        } catch {
            // Save errors are surfaced by SwiftData in the delegate
            // logs; there's no productive UI recovery here — the
            // user can retry from the same sheet next time.
        }
        onDismiss()
    }

    private func deleteAndDismiss(_ pin: TodoPin) {
        let store = TodoPinStore(context: context)
        try? store.delete(pin)
        onDismiss()
    }
}
#endif
