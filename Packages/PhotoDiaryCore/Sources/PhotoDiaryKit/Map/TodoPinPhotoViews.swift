#if canImport(UIKit)
import PhotoDiaryCore
import SwiftUI
import UIKit

extension TodoPinPhoto {
    /// The camera's image redrawn at the stored size, upright, as JPEG.
    @MainActor
    static func jpeg(from image: UIImage) -> Data? {
        let pixels = CGSize(
            width: image.size.width * image.scale, height: image.size.height * image.scale)
        let size = storedSize(for: pixels)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(
            withCompressionQuality: jpegQuality
        ) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// A todo pin's stored photo. Decoded once per photo rather than on
/// every render, since the editor re-renders on each keystroke.
struct TodoPinPhotoImage: View {
    let data: Data

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable()
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .task(id: data) { image = UIImage(data: data) }
        .accessibilityLabel("Photo of the place")
    }
}

/// The photo on its own, full screen, from the map callout.
struct TodoPinPhotoViewer: View {
    let data: Data
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TodoPinPhotoImage(data: data)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button("Close", systemImage: "xmark.circle.fill", action: onClose)
                .labelStyle(.iconOnly)
                .font(.title)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .gray.opacity(0.6))
                .padding()
        }
    }
}

/// The system camera, for a todo pin's snapshot.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
#endif
