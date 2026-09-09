import Foundation

/// Where screens keep the little state that makes a relaunch land where
/// the app was — the tab, the calendar's path, the map's camera — keyed
/// per scope. Durable across a system kill and a force quit, which is
/// why it is a store of our own and not scene restoration.
public protocol RestorationStore: Sendable {
    func load<T: Decodable & Sendable>(_ type: T.Type, forKey key: String) -> T?
    func save<T: Encodable & Sendable>(_ value: T?, forKey key: String)
}

public final class InMemoryRestorationStore: RestorationStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    public init() {}

    public func load<T: Decodable & Sendable>(_ type: T.Type, forKey key: String) -> T? {
        lock.withLock { values[key] }.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    public func save<T: Encodable & Sendable>(_ value: T?, forKey key: String) {
        let data = value.flatMap { try? JSONEncoder().encode($0) }
        lock.withLock { values[key] = data }
    }
}

public struct UserDefaultsRestorationStore: RestorationStore {
    // UserDefaults itself isn't Sendable; the suite name is, and the
    // lookup is cheap.
    private let suiteName: String?

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func load<T: Decodable & Sendable>(_ type: T.Type, forKey key: String) -> T? {
        defaults.data(forKey: "restore." + key).flatMap {
            try? JSONDecoder().decode(type, from: $0)
        }
    }

    public func save<T: Encodable & Sendable>(_ value: T?, forKey key: String) {
        defaults.set(value.flatMap { try? JSONEncoder().encode($0) }, forKey: "restore." + key)
    }
}
