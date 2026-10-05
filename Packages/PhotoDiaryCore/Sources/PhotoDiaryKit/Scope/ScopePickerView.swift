import SwiftUI

/// The front page: every paired instance with its galleries beneath.
/// Tapping the instance opens the Map and Calendar on all of its
/// galleries; tapping a gallery opens them on that one. Add and forget
/// instances here too.
public struct ScopePickerView: View {
    @Environment(InstanceRegistry.self) private var registry
    @State private var showPairing = false
    @State private var showSettings = false
    @Environment(\.stageCues) private var stageCues

    public init() {}

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Photo Diary")
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showPairing = true
                        } label: {
                            Label("Add instance", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showPairing) {
                    PairingView().environment(registry)
                }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .onAppear { if stageCues.takeSheet(.settings) { showSettings = true } }
        }
    }

    @ViewBuilder
    private var content: some View {
        if registry.instances.isEmpty {
            ContentUnavailableView {
                Label("No instances yet", systemImage: "server.rack")
            } description: {
                Text("Pair this device with a Photo Diary site to get started.")
            } actions: {
                Button("Add instance") { showPairing = true }
                    .buttonStyle(.borderedProminent)
                Button("Show the demo") { registry.add(DemoInstance()) }
            }
        } else {
            List {
                if let eviction = registry.eviction {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            message(for: eviction)
                            Spacer()
                            DismissButton { registry.dismissEviction() }
                        }
                        .font(.footnote)
                    }
                }
                ForEach(registry.instances, id: \.id) { instance in
                    InstanceSection(instance: instance)
                }
                if !registry.instances.contains(where: \.isDemo) {
                    Section {
                        Button("Show the demo") { registry.add(DemoInstance()) }
                    }
                }
            }
        }
    }

    private func message(for eviction: Eviction) -> Text {
        let name = eviction.instanceName
        switch eviction.reason {
        case .sessionExpired:
            return Text("Your pairing with \(name) has expired. Pair this device again.")
        case .galleryGone:
            return Text("The gallery you were viewing on \(name) is no longer there.")
        case .forbidden:
            return Text("\(name) no longer lets you see what you were viewing.")
        }
    }
}

/// One instance and its galleries. The galleries load on appear;
/// until then, or on failure, the instance row alone still works.
private struct InstanceSection: View {
    let instance: any Instance

    @Environment(InstanceRegistry.self) private var registry
    @State private var state: LoadState<[Gallery]> = .loading
    @State private var confirmingForget = false

    var body: some View {
        Section {
            Button {
                registry.enter(Scope(instanceId: instance.id))
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(instance.displayName).font(.headline)
                    Text(instance.isDemo ? "Built-in demo data" : "All galleries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button("Forget", role: .destructive) { confirmingForget = true }
            }
            galleryRows
        }
        .confirmationDialog(
            Text("Forget \(instance.displayName)?"), isPresented: $confirmingForget,
            titleVisibility: .visible
        ) {
            Button("Forget", role: .destructive) { registry.remove(id: instance.id) }
        } message: {
            Text(
                instance.isDemo
                    ? "The demo can be shown again from this page."
                    : "To see it again, pair this device with it again.")
        }
        .task(id: instance.id) { await load() }
    }

    @ViewBuilder
    private var galleryRows: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .empty:
            Text("No galleries").foregroundStyle(.secondary)
        case .failed(let failure):
            Label(failure.message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if failure.sessionExpired {
                SessionExpiredActions(instance: instance) { Task { await load() } }
            }
        case .loaded(let galleries):
            ForEach(galleries) { gallery in
                Button {
                    registry.enter(Scope(instanceId: instance.id, galleryId: gallery.id))
                } label: {
                    HStack {
                        Text(gallery.title)
                            .padding(.leading, 16)
                        Spacer()
                        if let count = gallery.photoCount {
                            Text("\(count)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(gallery.photoCount.map { "\($0) photos" } ?? "")
            }
        }
    }

    private func load() async {
        await LoadState.load(
            cached: { await instance.cachedGalleries() },
            fresh: { try await instance.listGalleries() },
            isEmpty: \.isEmpty
        ) { state = $0 }
    }
}
