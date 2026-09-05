import SwiftUI

/// Root view. Owns the `InstanceRegistry` for the process and hosts
/// the tab bar.
public struct AppShell: View {
    @State private var registry: InstanceRegistry
    private let imageLoader: any ImageLoader

    public init() {
        _registry = State(initialValue: InstanceRegistry(seedingDemo: true))
        self.imageLoader = DemoImageLoader()
    }

    public var body: some View {
        TabView {
            MapPhotoView()
                .tabItem { Label("Map", systemImage: "map") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
        }
        .environment(registry)
        .environment(\.imageLoader, ImageLoaderBox(imageLoader))
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
