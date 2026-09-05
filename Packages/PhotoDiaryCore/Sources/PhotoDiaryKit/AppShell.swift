import SwiftUI

/// Root view. Owns the `InstanceRegistry` for the process and hosts
/// the tab bar. Calendar is the real surface; Map is still a
/// placeholder until its own PR lands.
public struct AppShell: View {
    @State private var registry: InstanceRegistry
    private let imageLoader: any ImageLoader

    public init() {
        _registry = State(initialValue: InstanceRegistry(seedingDemo: true))
        self.imageLoader = DemoImageLoader()
    }

    public var body: some View {
        TabView {
            MapTabPlaceholder()
                .tabItem { Label("Map", systemImage: "map") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
        }
        .environment(registry)
        .environment(\.imageLoader, ImageLoaderBox(imageLoader))
    }
}

/// Minimal placeholder until MapSurfaceView lands. No 'Preview a
/// photo' plumbing — the calendar surface now covers the end-to-end
/// viewer path, so this can stay a straight message.
private struct MapTabPlaceholder: View {
    @Environment(InstanceRegistry.self) private var registry

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Map")
                .font(.title2.bold())
            Text("Coming in the next PR.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let name = registry.activeInstance?.displayName {
                Text("Active instance: \(name)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
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
