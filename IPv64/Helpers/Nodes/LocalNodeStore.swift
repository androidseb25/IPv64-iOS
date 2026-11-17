import Foundation
import IPv64

/// Direct node access stored on this device (Android `LocalNodeStore`, prefs `NODE64_LOCAL`).
/// Metadata (`<id>.url/.owner/.name/.proxy/.dns/.synced`) lives in the app-group UserDefaults under the prefix
/// `NODE64_LOCAL.`; the node API key lives in the Keychain (`NODE64_KEY.<id>`). Owner = the account's `User.uuid`.
nonisolated enum LocalNodeStore {
    struct Access: Hashable, Sendable {
        let url: String
        let key: String
    }

    private static let prefix = "NODE64_LOCAL."
    /// Test seam: an isolated suite replaces the app-group defaults.
    nonisolated(unsafe) static var overrideDefaults: UserDefaults?
    private static var defaults: UserDefaults { overrideDefaults ?? UserDefaults(suiteName: AppConfig.appGroup) ?? .standard }
    private static func key(_ id: String, _ field: String) -> String { "\(prefix)\(id).\(field)" }
    private static func secretAccount(_ id: String) -> String { "NODE64_KEY.\(id)" }

    /// URL + key for a node of `owner`, `nil` if none is stored or it belongs to another account.
    static func get(_ id: String, owner: String) -> Access? {
        guard !owner.isEmpty, defaults.string(forKey: key(id, "owner")) == owner,
              let url = defaults.string(forKey: key(id, "url")),
              let apiKey = try? SecureStore.readString(secretAccount(id)), !apiKey.isEmpty else { return nil }
        return Access(url: url, key: apiKey)
    }

    static func name(_ id: String) -> String? { defaults.string(forKey: key(id, "name")) }

    static func setName(_ id: String, _ name: String) {
        defaults.set(name, forKey: key(id, "name"))
        defaults.set(true, forKey: key(id, "dirty"))
    }

    /// Account owning the stored access of `id` (one entry per node id on this device).
    static func owner(_ id: String) -> String? { defaults.string(forKey: key(id, "owner")) }

    /// Stored URL without reading the Keychain (list rows).
    static func url(_ id: String) -> String? { defaults.string(forKey: key(id, "url")) }

    /// Sorted node ids of `owner` that have a stored URL.
    static func list(owner: String) -> [String] {
        let all = defaults.dictionaryRepresentation().reduce(into: [String: Any]()) { result, entry in
            if entry.key.hasPrefix(prefix) { result[String(entry.key.dropFirst(prefix.count))] = entry.value }
        }
        return localNodeIds(all, owner: owner)
    }

    /// Android `localNodeIds(all, owner)` on the un-prefixed key map. Pure.
    static func localNodeIds(_ all: [String: Any], owner: String) -> [String] {
        all.keys
            .filter { $0.hasSuffix(".url") }
            .map { String($0.dropLast(4)) }
            .filter { all["\($0).owner"] as? String == owner }
            .sorted()
    }

    /// Saves (or replaces) the access; `.name` is only written when non-nil.
    static func save(id: String, url: String, key apiKey: String, owner: String, name: String? = nil) throws {
        try SecureStore.write(Data(apiKey.utf8), account: secretAccount(id))
        defaults.set(url, forKey: key(id, "url"))
        defaults.set(owner, forKey: key(id, "owner"))
        if let name { defaults.set(name, forKey: key(id, "name")) }
        // Changed here: wins over the iCloud copy on the next sync (also when saved offline).
        defaults.set(true, forKey: key(id, "dirty"))
    }

    /// Set once the access was written to or imported from the iCloud Keychain (`NodeSyncStore`).
    static func isSynced(_ id: String) -> Bool { defaults.bool(forKey: key(id, "synced")) }
    /// Saved or renamed here and not yet written to the iCloud Keychain.
    static func isDirty(_ id: String) -> Bool { defaults.bool(forKey: key(id, "dirty")) }
    static func markSynced(_ id: String) {
        defaults.set(true, forKey: key(id, "synced"))
        defaults.removeObject(forKey: key(id, "dirty"))
    }

    static func proxyActive(_ id: String) -> Bool { defaults.bool(forKey: key(id, "proxy")) }
    static func dnsActive(_ id: String) -> Bool { defaults.bool(forKey: key(id, "dns")) }

    /// Android `isProxyModule`.
    static func isProxyModule(_ name: String) -> Bool { ["cdn64", "proxy64", "proxy"].contains(name.lowercased()) }

    /// Persists the proxy / DNS64 module flags from `node.status().modules`; writes only on change.
    static func saveModules(_ id: String, modules: [Node64.ModuleStatus]) {
        let proxy = modules.contains { isProxyModule($0.name) && $0.enabled == true }
        let dns = modules.contains { $0.name.lowercased() == "dns64" && $0.enabled == true }
        guard proxy != proxyActive(id) || dns != dnsActive(id) else { return }
        defaults.set(proxy, forKey: key(id, "proxy"))
        defaults.set(dns, forKey: key(id, "dns"))
    }

    static func remove(_ id: String) {
        for field in ["url", "owner", "name", "proxy", "dns", "synced", "dirty"] { defaults.removeObject(forKey: key(id, field)) }
        try? SecureStore.remove(secretAccount(id))
    }

    /// Deletes every node access of an account (account removed from this app).
    static func removeOwner(_ owner: String) {
        for (fullKey, value) in defaults.dictionaryRepresentation()
        where fullKey.hasPrefix(prefix) && fullKey.hasSuffix(".owner") && value as? String == owner {
            remove(String(fullKey.dropFirst(prefix.count).dropLast(".owner".count)))
        }
    }
}
