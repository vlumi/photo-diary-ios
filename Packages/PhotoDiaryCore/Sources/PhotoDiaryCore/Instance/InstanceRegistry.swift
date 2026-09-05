import Foundation
import Observation

/// The app's list of configured instances plus an active-instance
/// pointer. `@Observable` so SwiftUI views can rebind when the
/// registry mutates.
///
/// v1 seeds the DemoInstance on first launch. Real (RemoteInstance)
/// instances get added via the SSO pairing flow, which lands in a
/// later PR — for now the registry is demo-only.
///
/// The active instance is a single global — most UI surfaces are
/// scoped to whichever instance is active, switched from a top-level
/// Settings action.
@Observable
@MainActor
public final class InstanceRegistry {
    public private(set) var instances: [any Instance] = []
    public private(set) var activeInstanceId: String?

    public init(seedingDemo: Bool = true) {
        if seedingDemo {
            let demo = DemoInstance()
            instances = [demo]
            activeInstanceId = demo.id
        }
    }

    public var activeInstance: (any Instance)? {
        guard let id = activeInstanceId else { return nil }
        return instances.first(where: { $0.id == id })
    }

    public func setActive(_ id: String) {
        guard instances.contains(where: { $0.id == id }) else { return }
        activeInstanceId = id
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
    }

    public func remove(id: String) {
        instances.removeAll(where: { $0.id == id })
        if activeInstanceId == id {
            activeInstanceId = instances.first?.id
        }
    }
}
