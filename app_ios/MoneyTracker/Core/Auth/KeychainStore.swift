import Foundation
import Security
import Synchronization

/// Thin wrapper over generic-password Keychain items (FRONTEND_IOS §1: no library). Items are
/// readable after the first unlock so a background sync can use them, and never leave the device.
struct KeychainStore: Sendable {
    let service: String

    #if DEBUG
        /// Previews only: items live in this dictionary instead of the Keychain.
        final class Memory: Sendable {
            let items = Mutex<[String: Data]>([:])
        }

        var memory: Memory?
    #endif

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }

    func read(_ key: String) throws -> Data? {
        #if DEBUG
            if let memory { return memory.items.withLock { $0[key] } }
        #endif
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError.unexpectedStatus(status)
        }
    }

    func write(_ key: String, _ data: Data) throws {
        #if DEBUG
            if let memory {
                memory.items.withLock { $0[key] = data }
                return
            }
        #endif
        let update = SecItemUpdate(
            baseQuery(key) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw KeychainError.unexpectedStatus(update) }
        var add = baseQuery(key)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    func delete(_ key: String) throws {
        #if DEBUG
            if let memory {
                memory.items.withLock { _ = $0.removeValue(forKey: key) }
                return
            }
        #endif
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Removes every item of this service.
    func deleteAll() throws {
        #if DEBUG
            if let memory {
                memory.items.withLock { $0.removeAll() }
                return
            }
        #endif
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
