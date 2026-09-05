import SwiftUI

/// Root view. Owns the `InstanceRegistry` for the process and hands
/// the tab bar its two placeholder surfaces. Concrete Map + Calendar
/// implementations land in their own PRs; this shell is the seam they
/// slot into.
public struct AppShell: View {
    @State private var registry: InstanceRegistry

    public init() {
        _registry = State(initialValue: InstanceRegistry(seedingDemo: true))
    }

    public var body: some View {
        TabView {
            MapTabPlaceholder()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            CalendarTabPlaceholder()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
        }
        .environment(registry)
    }
}

private struct MapTabPlaceholder: View {
    @Environment(InstanceRegistry.self) private var registry

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Map")
                .font(.title2.bold())
            Text(activeSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var activeSummary: String {
        if let name = registry.activeInstance?.displayName {
            return "Active instance: \(name)"
        }
        return "No active instance"
    }
}

private struct CalendarTabPlaceholder: View {
    @Environment(InstanceRegistry.self) private var registry

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Calendar")
                .font(.title2.bold())
            Text(activeSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var activeSummary: String {
        if let name = registry.activeInstance?.displayName {
            return "Active instance: \(name)"
        }
        return "No active instance"
    }
}
