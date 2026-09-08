import Foundation

/// The registry's durable shape: which instance ids exist (hosts, plus
/// the demo sentinel) and which one is active. Cookies live in the
/// SessionStore, not here.
public protocol InstancePersistence: Sendable {
    /// nil means nothing was ever saved — first launch.
    func loadInstanceIds() -> [String]?
    func saveInstanceIds(_ ids: [String])
    func loadActiveId() -> String?
    func saveActiveId(_ id: String?)
}

public final class InMemoryInstancePersistence: InstancePersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var ids: [String]?
    private var active: String?

    public init(ids: [String]? = nil, active: String? = nil) {
        self.ids = ids
        self.active = active
    }

    public func loadInstanceIds() -> [String]? { lock.withLock { ids } }
    public func saveInstanceIds(_ ids: [String]) { lock.withLock { self.ids = ids } }
    public func loadActiveId() -> String? { lock.withLock { active } }
    public func saveActiveId(_ id: String?) { lock.withLock { active = id } }
}

public struct UserDefaultsInstancePersistence: InstancePersistence {
    private static let idsKey = "instances.ids"
    private static let activeKey = "instances.active"

    public init() {}

    public func loadInstanceIds() -> [String]? {
        UserDefaults.standard.stringArray(forKey: Self.idsKey)
    }
    public func saveInstanceIds(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: Self.idsKey)
    }
    public func loadActiveId() -> String? {
        UserDefaults.standard.string(forKey: Self.activeKey)
    }
    public func saveActiveId(_ id: String?) {
        UserDefaults.standard.set(id, forKey: Self.activeKey)
    }
}
