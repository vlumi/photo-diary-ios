import SwiftUI

/// Root view. Owns the `InstanceRegistry` for the process and hands
/// the tab bar its two placeholder surfaces. Concrete Map + Calendar
/// implementations land in their own PRs; this shell is the seam they
/// slot into.
public struct AppShell: View {
    @State private var registry: InstanceRegistry
    private let imageLoader: any ImageLoader

    public init() {
        _registry = State(initialValue: InstanceRegistry(seedingDemo: true))
        self.imageLoader = DemoImageLoader()
    }

    public var body: some View {
        TabView {
            SurfacePlaceholder(kind: .map)
                .tabItem { Label("Map", systemImage: "map") }

            SurfacePlaceholder(kind: .calendar)
                .tabItem { Label("Calendar", systemImage: "calendar") }
        }
        .environment(registry)
        .environment(\.imageLoader, ImageLoaderBox(imageLoader))
    }
}

/// Placeholder tab that lets you preview the viewer end-to-end while
/// the real Map + Calendar surfaces are still being built. Fetches
/// the first photo from the active instance's first gallery, then
/// mounts PhotoViewerSheet in a full-screen cover.
private struct SurfacePlaceholder: View {
    enum Kind {
        case map, calendar

        var title: String { self == .map ? "Map" : "Calendar" }
        var symbol: String { self == .map ? "map" : "calendar" }
    }

    let kind: Kind

    @Environment(InstanceRegistry.self) private var registry
    @Environment(\.imageLoader) private var loaderBox
    @State private var previewPhoto: Photo?
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: kind.symbol)
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text(kind.title)
                .font(.title2.bold())
            Text(activeSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Preview a photo") { Task { await loadFirstPhoto() } }
                .buttonStyle(.borderedProminent)
                .disabled(registry.activeInstance == nil)
            if let loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .modifier(PreviewCoverModifier(photo: $previewPhoto, loader: loaderBox.loader))
    }

    private var activeSummary: String {
        if let name = registry.activeInstance?.displayName {
            return "Active instance: \(name)"
        }
        return "No active instance"
    }

    private func loadFirstPhoto() async {
        loadError = nil
        guard let instance = registry.activeInstance else { return }
        do {
            guard let firstGallery = try await instance.listGalleries().first else {
                loadError = "No galleries on this instance."
                return
            }
            guard let first = try await instance.listPhotos(inGallery: firstGallery.id).first
            else {
                loadError = "No photos in \(firstGallery.title)."
                return
            }
            previewPhoto = first
        } catch {
            loadError = "Fetch failed: \(error.localizedDescription)"
        }
    }
}

// Presents PhotoViewerSheet as a full-screen cover on iOS; on macOS
// (where swift test runs) fullScreenCover(item:) is unavailable, so
// we degrade to a sheet — the app itself never runs on macOS.
private struct PreviewCoverModifier: ViewModifier {
    @Binding var photo: Photo?
    let loader: any ImageLoader

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content.fullScreenCover(item: $photo) { photo in
            PhotoViewerSheet(photo: photo, loader: loader, onDismiss: { self.photo = nil })
        }
        #else
        content.sheet(item: $photo) { photo in
            PhotoViewerSheet(photo: photo, loader: loader, onDismiss: { self.photo = nil })
        }
        #endif
    }
}

// MARK: - Environment plumbing for the loader
//
// Wraps `any ImageLoader` in a concrete type so it can ride the
// SwiftUI environment (existentials need a wrapper). Read-only from
// the app's perspective — the loader is chosen at AppShell init.

struct ImageLoaderBox {
    let loader: any ImageLoader
    init(_ loader: any ImageLoader) { self.loader = loader }
}

private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue = ImageLoaderBox(DemoImageLoader())
}

extension EnvironmentValues {
    var imageLoader: ImageLoaderBox {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
}
