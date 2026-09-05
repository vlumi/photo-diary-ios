import SwiftData
import SwiftUI

/// Root view. Owns the `InstanceRegistry` for the process and hosts
/// the tab bar. Also mounts the SwiftData ModelContainer for todo
/// pins so any surface that wants @Query'd pins gets one.
public struct AppShell: View {
    @State private var registry: InstanceRegistry
    private let imageLoader: any ImageLoader
    private let todoPinContainer: ModelContainer

    public init() {
        _registry = State(initialValue: InstanceRegistry(seedingDemo: true))
        self.imageLoader = DemoImageLoader()
        do {
            self.todoPinContainer = try ModelContainer(for: TodoPin.self)
        } catch {
            // A ModelContainer failure at launch is not recoverable
            // and indicates a genuine environmental problem
            // (permissions, disk full, corrupt store). Better to
            // crash loudly with the underlying reason than to
            // present a maimed app that silently loses writes.
            fatalError("Failed to create TodoPin ModelContainer: \(error)")
        }
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
        .modelContainer(todoPinContainer)
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
