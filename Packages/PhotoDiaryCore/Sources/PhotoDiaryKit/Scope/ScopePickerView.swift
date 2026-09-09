import SwiftUI

/// The front page: every paired instance with its galleries beneath.
/// Tapping the instance opens the Map and Calendar on all of its
/// galleries; tapping a gallery opens them on that one. Add and forget
/// instances here too.
public struct ScopePickerView: View {
    @Environment(InstanceRegistry.self) private var registry
    @State private var showPairing = false

    public init() {}

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Photo Diary")
                .toolbar {
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
            }
        } else {
            List {
                ForEach(registry.instances, id: \.id) { instance in
                    InstanceSection(instance: instance)
                }
            }
        }
    }
}

/// One instance and its galleries. The galleries load on appear;
/// until then, or on failure, the instance row alone still works.
private struct InstanceSection: View {
    let instance: any Instance

    @Environment(InstanceRegistry.self) private var registry
    @State private var state: LoadState<[Gallery]> = .loading

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
                Button("Forget", role: .destructive) { registry.remove(id: instance.id) }
            }
            galleryRows
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
        state = .loading
        do {
            let galleries = try await instance.listGalleries()
            state = galleries.isEmpty ? .empty : .loaded(galleries)
        } catch {
            state = .failed(LoadFailure(error))
        }
    }
}
