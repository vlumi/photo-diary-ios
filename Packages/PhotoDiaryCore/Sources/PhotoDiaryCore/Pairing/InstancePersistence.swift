import Foundation

/// The registry's durable shape: which instance ids exist (hosts, plus
/// the demo sentinel) and which scope was open. Cookies live in the
/// SessionStore, not here.
public protocol InstancePersistence: Sendable {
    /// nil means nothing was ever saved — first launch.
    func loadInstanceIds() -> [String]?
    func saveInstanceIds(_ ids: [String])
    /// nil means the front page was showing.
    func loadScope() -> Scope?
    func saveScope(_ scope: Scope?)
}

public final class InMemoryInstancePersistence: InstancePersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var ids: [String]?
    private var scope: Scope?

    public init(ids: [String]? = nil, scope: Scope? = nil) {
        self.ids = ids
        self.scope = scope
    }

    public func loadInstanceIds() -> [String]? { lock.withLock { ids } }
    public func saveInstanceIds(_ ids: [String]) { lock.withLock { self.ids = ids } }
    public func loadScope() -> Scope? { lock.withLock { scope } }
    public func saveScope(_ scope: Scope?) { lock.withLock { self.scope = scope } }
}

public struct UserDefaultsInstancePersistence: InstancePersistence {
    private static let idsKey = "instances.ids"
    private static let scopeKey = "instances.scope"

    public init() {}

    public func loadInstanceIds() -> [String]? {
        UserDefaults.standard.stringArray(forKey: Self.idsKey)
    }
    public func saveInstanceIds(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: Self.idsKey)
    }
    public func loadScope() -> Scope? {
        guard let data = UserDefaults.standard.data(forKey: Self.scopeKey) else { return nil }
        return try? JSONDecoder().decode(Scope.self, from: data)
    }
    public func saveScope(_ scope: Scope?) {
        let data = scope.flatMap { try? JSONEncoder().encode($0) }
        UserDefaults.standard.set(data, forKey: Self.scopeKey)
    }
}
