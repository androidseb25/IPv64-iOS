import Foundation
import Security

/// Direct node access synced across the user's devices through the iCloud Keychain.
/// One synchronizable generic password per node (service `net.ipv64.nodesync`, account `<accountId>.<nodeId>`,
/// value JSON `Entry`), scoped by the stable ipv64.net account id. `LocalNodeStore` stays the source the app reads.
nonisolated enum NodeSyncStore {
    typealias Entry = NodeSyncPlan.Entry

    /// App-group defaults key of the "Sync with iCloud" setting (default on).
    static let enabledKey = "NODE64_SYNC_ICLOUD"
    static var isEnabled: Bool {
        UserDefaults(suiteName: AppConfig.appGroup)?.object(forKey: enabledKey) as? Bool ?? true
    }

    private static func query() throws -> [String: Any] {
        try [kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: "net.ipv64.nodesync",
             kSecAttrAccessGroup as String: SecureStore.accessGroup()]
    }

    /// Writes the stored access of `id` to the iCloud Keychain and marks it as synced; mirrors to CloudKit.
    @MainActor static func push(_ id: String, account: Int, owner: String) {
        pushKeychain(id, account: account, owner: owner)
        mirrorToCloudKit(account: account, owner: owner)
    }

    private static func pushKeychain(_ id: String, account: Int, owner: String) {
        guard let access = LocalNodeStore.get(id, owner: owner), !isDebugMock(access.key) else { return }
        let entry = Entry(url: access.url, key: access.key, name: LocalNodeStore.name(id), updatedAt: .now)
        if write(entry, id: id, account: account) { LocalNodeStore.markSynced(id) }
    }

    /// The Apple TV cannot read the iCloud Keychain: mirrors the account's full local set to CloudKit.
    @MainActor private static func mirrorToCloudKit(account: Int, owner: String, removed: [String] = []) {
        let nodes = LocalNodeStore.list(owner: owner).compactMap { id -> NodeCloudStore.Node? in
            guard let access = LocalNodeStore.get(id, owner: owner), !isDebugMock(access.key) else { return nil }
            return .init(nodeId: id, account: account, url: access.url, key: access.key, name: LocalNodeStore.name(id))
        }
        NodeCloudStore.mirror(nodes, removed: removed, account: account)
    }

    /// "Forget access": replaces the synced access of `id` with a deletion marker, so it is removed on all
    /// devices but a keychain that is merely missing items (iCloud Keychain reset) never removes anything.
    @discardableResult
    @MainActor static func delete(_ id: String, account: Int) -> Bool {
        NodeCloudStore.delete(id, account: account)
        return write(Entry(url: "", key: "", name: nil, updatedAt: .now, deleted: true), id: id, account: account)
    }

    private static func write(_ entry: Entry, id: String, account: Int) -> Bool {
        guard let data = try? JSONEncoder().encode(entry), var request = try? query() else { return false }
        request[kSecAttrAccount as String] = "\(account).\(id)"
        request[kSecAttrSynchronizable as String] = true
        // Synced items cannot be ThisDeviceOnly.
        let attributes: [String: Any] = [kSecValueData as String: data,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        var status = SecItemUpdate(request as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(request.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        return status == errSecSuccess
    }

    /// Synced entries of `account` by node id; `nil` when the Keychain cannot be read (then nothing may be removed).
    static func entries(account: Int) -> [String: Entry]? {
        guard var request = try? query() else { return nil }
        request[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        request[kSecReturnAttributes as String] = true
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return [:] }
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return nil }
        let prefix = "\(account)."
        return items.reduce(into: [:]) { entries, item in
            guard let name = item[kSecAttrAccount as String] as? String, name.hasPrefix(prefix),
                  let data = item[kSecValueData as String] as? Data,
                  let entry = try? JSONDecoder().decode(Entry.self, from: data),
                  entry.deleted == true || (!entry.url.isEmpty && NodesLogic.isValidApiKey(entry.key)) else { return }
            entries[String(name.dropFirst(prefix.count))] = entry
        }
    }

    /// Two-way sync of `account`: uploads access changed here or missing in iCloud, imports access from
    /// other devices and removes access forgotten on another device.
    @MainActor static func sync(account: Int, owner: String) {
        guard let synced = entries(account: account) else { return }
        let ids = LocalNodeStore.list(owner: owner)
        let local = ids.reduce(into: [String: Entry]()) { local, id in
            guard let access = LocalNodeStore.get(id, owner: owner) else { return }
            local[id] = Entry(url: access.url, key: access.key, name: LocalNodeStore.name(id), updatedAt: .distantPast)
        }
        let otherOwner = Set(synced.keys.filter { id in LocalNodeStore.owner(id).map { $0 != owner } ?? false })
        let changes = NodeSyncPlan.plan(local: local, synced: synced, dirty: Set(ids.filter(LocalNodeStore.isDirty)),
                           otherOwner: otherOwner)
        changes.push.forEach { pushKeychain($0, account: account, owner: owner) }
        for (id, entry) in changes.upsert {
            guard (try? LocalNodeStore.save(id: id, url: entry.url, key: entry.key, owner: owner, name: entry.name)) != nil else { continue }
            LocalNodeStore.markSynced(id)
        }
        changes.remove.forEach(LocalNodeStore.remove)
        changes.inSync.forEach(LocalNodeStore.markSynced)
        mirrorToCloudKit(account: account, owner: owner, removed: changes.remove)
    }


    /// DEBUG mock nodes (`DebugFixtures`, key "node64_mock") never leave the device.
    private static func isDebugMock(_ key: String) -> Bool {
        #if DEBUG
        return key == "node64_mock"
        #else
        return false
        #endif
    }
}
