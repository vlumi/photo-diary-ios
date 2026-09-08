import Foundation
import Observation

/// The app's list of configured instances plus an active-instance
/// pointer. `@Observable` so SwiftUI views can rebind when the
/// registry mutates.
///
/// Durable: the id list and active id go to InstancePersistence on
/// every change; remote sessions live in the SessionStore and are
/// rebuilt into RemoteInstances on launch. The demo instance is just
/// another id in the list — seeded on first launch, gone once removed.
///
/// The active instance is a single global — most UI surfaces are
/// scoped to whichever instance is active, switched from Settings.
@Observable
@MainActor
public final class InstanceRegistry {
    public private(set) var instances: [any Instance] = []
    public private(set) var activeInstanceId: String?
    /// Shared with the pairing flow so a freshly paired instance
    /// persists its cookies the same way a restored one does.
    public let remoteFactory: RemoteInstanceFactory

    private let persistence: any InstancePersistence
    private let sessionStore: any SessionStore

    /// Test / preview convenience: nothing persists.
    public convenience init(seedingDemo: Bool = true) {
        self.init(
            persistence: InMemoryInstancePersistence(),
            sessionStore: InMemorySessionStore(),
            seedingDemo: seedingDemo
        )
    }

    /// Restores whatever was persisted. On first launch (nothing
    /// saved yet) seeds the demo instance when `seedingDemo`.
    public init(
        persistence: any InstancePersistence,
        sessionStore: any SessionStore,
        seedingDemo: Bool = true
    ) {
        self.persistence = persistence
        self.sessionStore = sessionStore
        self.remoteFactory = RemoteInstanceFactory(sessionStore: sessionStore)

        let ids = persistence.loadInstanceIds() ?? (seedingDemo ? [DemoInstance.instanceId] : [])
        instances = ids.map { id -> any Instance in
            if id == DemoInstance.instanceId { return DemoInstance() }
            return remoteFactory.restore(host: id)
        }
        let savedActive = persistence.loadActiveId()
        activeInstanceId =
            instances.contains(where: { $0.id == savedActive }) ? savedActive : instances.first?.id
        persist()
    }

    public var activeInstance: (any Instance)? {
        guard let id = activeInstanceId else { return nil }
        return instances.first(where: { $0.id == id })
    }

    public func setActive(_ id: String) {
        guard instances.contains(where: { $0.id == id }) else { return }
        activeInstanceId = id
        persist()
    }

    public func add(_ instance: any Instance) {
        // Preserve identity: if an instance with the same id is
        // already registered, replace it rather than appending a
        // duplicate.
        if let idx = instances.firstIndex(where: { $0.id == instance.id }) {
            instances[idx] = instance
        } else {
            instances.append(instance)
        }
        if activeInstanceId == nil {
            activeInstanceId = instance.id
        }
        persist()
    }

    /// Forgets the instance and, for a remote one, its session.
    public func remove(id: String) {
        guard let removed = instances.first(where: { $0.id == id }) else { return }
        instances.removeAll(where: { $0.id == id })
        if !removed.isDemo {
            try? sessionStore.delete(host: id)
        }
        if activeInstanceId == id {
            activeInstanceId = instances.first?.id
        }
        persist()
    }

    private func persist() {
        persistence.saveInstanceIds(instances.map(\.id))
        persistence.saveActiveId(activeInstanceId)
    }
}
