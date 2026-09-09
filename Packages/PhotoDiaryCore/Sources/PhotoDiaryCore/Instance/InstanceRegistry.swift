import Foundation
import Observation

/// The app's list of configured instances plus the open scope: which
/// instance (and optionally which of its galleries) the Map and
/// Calendar show, or nil while the front page is up. `@Observable` so
/// SwiftUI views can rebind when the registry mutates.
///
/// Durable: the id list and scope go to InstancePersistence on every
/// change, so a relaunch lands where the app was; remote sessions live
/// in the SessionStore and are rebuilt into RemoteInstances on launch.
/// The demo instance is just another id in the list — seeded on first
/// launch, gone once removed.
@Observable
@MainActor
public final class InstanceRegistry {
    public private(set) var instances: [any Instance] = []
    public private(set) var scope: Scope?
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
    /// saved yet) seeds the demo instance when `seedingDemo`. A saved
    /// scope whose instance is gone is dropped: the front page shows.
    public init(
        persistence: any InstancePersistence,
        sessionStore: any SessionStore,
        cache: ResponseCache? = nil,
        seedingDemo: Bool = true
    ) {
        self.persistence = persistence
        self.sessionStore = sessionStore
        self.remoteFactory = RemoteInstanceFactory(sessionStore: sessionStore, cache: cache)

        let ids = persistence.loadInstanceIds() ?? (seedingDemo ? [DemoInstance.instanceId] : [])
        instances = ids.map { id -> any Instance in
            if id == DemoInstance.instanceId { return DemoInstance() }
            return remoteFactory.restore(origin: RemoteInstanceFactory.canonicalOrigin(id))
        }
        if let saved = persistence.loadScope() {
            let canonical = Scope(
                instanceId: RemoteInstanceFactory.canonicalOrigin(saved.instanceId),
                galleryId: saved.galleryId)
            scope = instances.contains(where: { $0.id == canonical.instanceId }) ? canonical : nil
        }
        persist()
    }

    public var activeInstanceId: String? { scope?.instanceId }

    public var activeInstance: (any Instance)? {
        guard let id = activeInstanceId else { return nil }
        return instances.first(where: { $0.id == id })
    }

    /// Open the Map and Calendar on this scope. Ignored for an
    /// instance the registry doesn't know.
    public func enter(_ scope: Scope) {
        guard instances.contains(where: { $0.id == scope.instanceId }) else { return }
        self.scope = scope
        persist()
    }

    /// Back to the front page.
    public func leaveScope() {
        scope = nil
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
        persist()
    }

    /// Forgets the instance and, for a remote one, its session. If it
    /// was the open scope, the front page shows.
    public func remove(id: String) {
        guard let removed = instances.first(where: { $0.id == id }) else { return }
        instances.removeAll(where: { $0.id == id })
        if !removed.isDemo {
            try? sessionStore.delete(host: id)
            remoteFactory.cache?.clear(origin: id)
        }
        if scope?.instanceId == id {
            scope = nil
        }
        persist()
    }

    private func persist() {
        persistence.saveInstanceIds(instances.map(\.id))
        persistence.saveScope(scope)
    }
}
