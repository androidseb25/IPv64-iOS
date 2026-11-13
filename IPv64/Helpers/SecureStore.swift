import Foundation
import Security

/// Shared by the app and widget; never falls back to plaintext storage.
nonisolated enum SecureStore {
    static func accessGroup() throws -> String {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "SecureKeychainAccessGroup") as? String,
              !group.isEmpty, !group.contains("$(") else {
            throw StoreError.configuration
        }
        return group
    }

    private static func query(_ account: String) throws -> [String: Any] {
        try [kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: "net.ipv64.credentials",
             kSecAttrAccount as String: account,
             kSecAttrAccessGroup as String: accessGroup()]
    }

    static func read(_ account: String) throws -> Data? {
        var request = try query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw StoreError.status(status) }
        return result as? Data
    }

    static func readString(_ account: String) throws -> String {
        String(data: try read(account) ?? Data(), encoding: .utf8) ?? ""
    }

    static func write(_ data: Data, account: String) throws {
        let request = try query(account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(request as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let addStatus = SecItemAdd(request.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw StoreError.status(addStatus) }
        } else if status != errSecSuccess {
            throw StoreError.status(status)
        }
    }

    static func remove(_ account: String) throws {
        let status = SecItemDelete(try query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreError.status(status) }
    }

    enum StoreError: LocalizedError {
        case configuration, status(OSStatus)
        var errorDescription: String? {
            "Your credentials could not be accessed securely. Unlock your device and try again."
        }
    }
}
