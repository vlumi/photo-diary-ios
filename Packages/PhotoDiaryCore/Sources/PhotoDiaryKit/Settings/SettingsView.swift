import SwiftUI

/// Instance registry surface: which instances exist, which is active,
/// add one via pairing, swipe to forget one (drops its session too).
public struct SettingsView: View {
    @Environment(InstanceRegistry.self) private var registry
    @State private var showPairing = false

    public init() {}

    private struct Row: Identifiable {
        let id: String
        let name: String
        let isDemo: Bool
    }

    private var rows: [Row] {
        registry.instances.map { Row(id: $0.id, name: $0.displayName, isDemo: $0.isDemo) }
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Instances") {
                    ForEach(rows) { row in
                        Button {
                            registry.setActive(row.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name)
                                        .foregroundStyle(.primary)
                                    if row.isDemo {
                                        Text("Built-in demo data")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if row.id == registry.activeInstanceId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(
                            row.id == registry.activeInstanceId ? .isSelected : [])
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            registry.remove(id: rows[offset].id)
                        }
                    }
                }
                Section {
                    Button {
                        showPairing = true
                    } label: {
                        Label("Add instance", systemImage: "plus")
                    }
                } footer: {
                    Text(
                        "Pair from the site: user menu → Pair a device. "
                            + "Swipe an instance to forget it."
                    )
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPairing) {
                PairingView()
                    .environment(registry)
            }
        }
    }
}
