import Foundation
import Security

/// Where a host's session cookies live between launches. Keyed by
/// host, which is also the RemoteInstance id.
public protocol SessionStore: Sendable {
    func load(host: String) throws -> SessionCookies?
    func save(_ cookies: SessionCookies, host: String) throws
    func delete(host: String) throws
}

/// Test / preview store. Nothing survives the process.
public final class InMemorySessionStore: SessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String: SessionCookies] = [:]

    public init() {}

    public func load(host: String) throws -> SessionCookies? {
        lock.withLock { entries[host] }
    }
    public func save(_ cookies: SessionCookies, host: String) throws {
        lock.withLock { entries[host] = cookies }
    }
    public func delete(host: String) throws {
        _ = lock.withLock { entries.removeValue(forKey: host) }
    }
}

public struct KeychainError: Error, Sendable {
    public let status: OSStatus
}

/// Generic-password Keychain items: service = app, account = host,
/// value = JSON-encoded SessionCookies. AfterFirstUnlock so a
/// background refresh after reboot can read the refresh token.
public struct KeychainSessionStore: SessionStore {
    private let service: String

    public init(service: String = "fi.misaki.photodiary.session") {
        self.service = service
    }

    public func load(host: String) throws -> SessionCookies? {
        var query = baseQuery(host: host)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError(status: status)
        }
        return try JSONDecoder().decode(SessionCookies.self, from: data)
    }

    public func save(_ cookies: SessionCookies, host: String) throws {
        let data = try JSONEncoder().encode(cookies)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let query = baseQuery(host: host)
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let added = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
            return
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func delete(host: String) throws {
        let status = SecItemDelete(baseQuery(host: host) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private func baseQuery(host: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host,
        ]
    }
}
