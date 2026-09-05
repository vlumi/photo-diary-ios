import SwiftUI

/// Bottom-sheet wrapper around PhotoViewer. Owns the load lifecycle
/// (async fetch via the injected ImageLoader), a close button, and the
/// black scrim behind the image. Sits above whichever surface routed
/// to it — grid, map pin, calendar cell.
public struct PhotoViewerSheet: View {
    private let photo: Photo
    private let loader: any ImageLoader
    private let onDismiss: () -> Void

    @State private var state: LoadState = .loading

    private enum LoadState {
        case loading
        case loaded(PlatformImage)
        case failed(String)
    }

    public init(
        photo: Photo,
        loader: any ImageLoader,
        onDismiss: @escaping () -> Void
    ) {
        self.photo = photo
        self.loader = loader
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            closeButton
                .padding(.top, 8)
                .padding(.trailing, 8)
        }
        .background(Color.black.ignoresSafeArea())
        .task(id: photo.id) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let image):
            PhotoViewer(image: image)
        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
        .accessibilityLabel("Close")
    }

    private func load() async {
        state = .loading
        do {
            let image = try await loader.loadImage(from: photo.displayImageURL)
            state = .loaded(image)
        } catch {
            state = .failed("Couldn't load photo: \(error.localizedDescription)")
        }
    }
}
