import Foundation
import Observation

/// The id list and scope are saved on every change, so a relaunch lands
/// where the app was. The demo is just another id: seeded on first
/// launch, gone once removed.
@Observable
@MainActor
public final class InstanceRegistry {
    public private(set) var instances: [any Instance] = []
    public private(set) var scope: Scope?
    /// For the front page to say; cleared by dismissEviction() or when a
    /// scope opens.
    public private(set) var eviction: Eviction?
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

    /// A saved scope whose instance is gone is dropped.
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
            // Only remote ids are origins; the demo's sentinel must
            // not be turned into "https://demo".
            let instanceId =
                saved.instanceId == DemoInstance.instanceId
                ? saved.instanceId : RemoteInstanceFactory.canonicalOrigin(saved.instanceId)
            let canonical = Scope(instanceId: instanceId, galleryId: saved.galleryId)
            scope = instances.contains(where: { $0.id == canonical.instanceId }) ? canonical : nil
        }
        persist()
    }

    public var activeInstanceId: String? { scope?.instanceId }

    public var activeInstance: (any Instance)? {
        guard let id = activeInstanceId else { return nil }
        return instances.first(where: { $0.id == id })
    }

    /// Ignored for an instance the registry doesn't know.
    public func enter(_ scope: Scope) {
        guard instances.contains(where: { $0.id == scope.instanceId }) else { return }
        self.scope = scope
        eviction = nil
        persist()
    }

    /// True when the failure meant the scope can no longer be shown and
    /// it was left. Any other failure is the screen's to show.
    @discardableResult
    public func evictIfAccessLost(_ error: any Error) -> Bool {
        guard let scope, let error = error as? InstanceError, error.deniesAccess else {
            return false
        }
        let cache = remoteFactory.cache
        let reason: Eviction.Reason
        switch error {
        case .sessionExpired:
            reason = .sessionExpired
            cache?.clear(origin: scope.instanceId)
        case .galleryNotFound:
            reason = .galleryGone
            if let galleryId = scope.galleryId {
                cache?.clear(origin: scope.instanceId, key: "photos/" + galleryId)
            }
        default:
            reason = .forbidden
        }
        eviction = Eviction(
            scope: scope, instanceName: activeInstance?.displayName ?? scope.instanceId,
            reason: reason)
        self.scope = nil
        persist()
        return true
    }

    public func dismissEviction() {
        eviction = nil
    }

    public func leaveScope() {
        scope = nil
        persist()
    }

    public func add(_ instance: any Instance) {
        if let idx = instances.firstIndex(where: { $0.id == instance.id }) {
            if let replaced = instances[idx] as? RemoteInstance, replaced !== instance as AnyObject
            {
                Task { await replaced.signOut() }
            }
            instances[idx] = instance
        } else {
            instances.append(instance)
        }
        persist()
    }

    public func remove(id: String) {
        guard let removed = instances.first(where: { $0.id == id }) else { return }
        instances.removeAll(where: { $0.id == id })
        if let remote = removed as? RemoteInstance {
            Task { await remote.signOut() }
        }
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

/// The scope the app was thrown out of, and why.
public struct Eviction: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case sessionExpired
        case galleryGone
        case forbidden
    }

    public let scope: Scope
    public let instanceName: String
    public let reason: Reason
}
