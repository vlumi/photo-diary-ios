import SwiftUI

/// Async-loaded square thumbnail backed by our ImageLoader (not
/// SwiftUI's AsyncImage — that one is URLSession-only and doesn't
/// know about photodiary-demo://). Placeholder while loading, subtle
/// warning tint on failure. Grids can drop these in with no per-cell
/// state management.
public struct PhotoThumbnail: View {
    private let url: URL
    private let loader: any ImageLoader

    @State private var state: LoadState = .loading

    private enum LoadState {
        case loading
        case loaded(PlatformImage)
        case failed
    }

    public init(url: URL, loader: any ImageLoader) {
        self.url = url
        self.loader = loader
    }

    public var body: some View {
        content
            .aspectRatio(1, contentMode: .fit)
            .background(Color.secondary.opacity(0.1))
            .clipped()
            .task(id: url) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            Color.secondary.opacity(0.1)
        case .loaded(let image):
            swiftUIImage(image)
                .resizable()
                .scaledToFill()
        case .failed:
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func swiftUIImage(_ image: PlatformImage) -> Image {
        #if canImport(UIKit)
        Image(uiImage: image)
        #else
        Image(nsImage: image)
        #endif
    }

    private func load() async {
        do {
            let image = try await loader.loadImage(from: url)
            state = .loaded(image)
        } catch {
            state = .failed
        }
    }
}
