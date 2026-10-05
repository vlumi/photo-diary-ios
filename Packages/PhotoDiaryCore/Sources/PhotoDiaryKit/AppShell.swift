import SwiftData
import SwiftUI

/// Root view. A staged launch (LaunchStage, for the store screenshots)
/// keeps everything in memory.
public struct AppShell: View {
    @State private var registry: InstanceRegistry
    private let imageLoader: any ImageLoader
    private let restoration: any RestorationStore
    private let todoPinContainer: ModelContainer
    private let stageCues: StageCues
    private let stage: LaunchStage?
    @State private var pendingTicket: PairingTicket?
    @State private var selectedTab: AppTab = .map
    @State private var focus = PhotoFocusStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {
        let stage = LaunchStage.current
        let registry: InstanceRegistry
        if stage?.signIn != nil {
            // Only the demo and the instance signed in to, so neither the
            // simulator's pairings nor its Keychain are touched.
            registry = InstanceRegistry(seedingDemo: true)
        } else {
            let persistence = UserDefaultsInstancePersistence()
            registry = InstanceRegistry(
                persistence: stage == nil ? persistence : UnsavedInstancePersistence(persistence),
                sessionStore: KeychainSessionStore(),
                cache: ResponseCache.inCaches()
            )
        }
        stage?.open(in: registry)
        _registry = State(initialValue: registry)
        self.stage = stage
        self.restoration =
            stage?.restoration(for: stage?.scope ?? registry.scope)
            ?? UserDefaultsRestorationStore()
        self.stageCues = StageCues(stage)
        self.imageLoader = SchemeRoutingImageLoader()
        do {
            self.todoPinContainer =
                try stage?.todoPinContainer() ?? ModelContainer(for: TodoPin.self)
        } catch {
            // Unrecoverable (permissions, disk full, corrupt store): crash
            // with the reason rather than run on and silently lose writes.
            fatalError("Failed to create TodoPin ModelContainer: \(error)")
        }
    }

    public var body: some View {
        Group {
            if registry.scope == nil {
                ScopePickerView()
                    .transition(.move(edge: .leading))
            } else {
                tabs
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: registry.scope == nil)
        .environment(registry)
        .environment(focus)
        .environment(\.imageLoader, imageLoader)
        .environment(\.restoration, restoration)
        .environment(\.stageCues, stageCues)
        .modelContainer(todoPinContainer)
        .task { await stage?.signIn(into: registry) }
        .onOpenURL { url in
            // Same-device pairing: the site's "Open in app" link.
            if let ticket = PairingTicket.parse(url) {
                pendingTicket = ticket
            }
        }
        .sheet(item: $pendingTicket) { ticket in
            PairingView(initialTicket: ticket)
                .environment(registry)
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            MapPhotoView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(AppTab.map)

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)
        }
        .onChange(of: focus.pendingOnMap?.id) {
            if focus.pendingOnMap != nil { selectedTab = .map }
        }
        .onChange(of: focus.pendingInCalendar?.id) {
            if focus.pendingInCalendar != nil { selectedTab = .calendar }
        }
        .onChange(of: registry.scope, initial: true) {
            guard let scope = registry.scope else { return }
            selectedTab = restoration.load(AppTab.self, forKey: "tab." + scope.key) ?? .map
        }
        .onChange(of: selectedTab) {
            guard let scope = registry.scope else { return }
            restoration.save(selectedTab, forKey: "tab." + scope.key)
        }
    }
}

// MARK: - Environment

private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue: any ImageLoader = SchemeRoutingImageLoader()
}

private struct RestorationKey: EnvironmentKey {
    static let defaultValue: any RestorationStore = InMemoryRestorationStore()
}

extension EnvironmentValues {
    var imageLoader: any ImageLoader {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }

    var restoration: any RestorationStore {
        get { self[RestorationKey.self] }
        set { self[RestorationKey.self] = newValue }
    }
}
