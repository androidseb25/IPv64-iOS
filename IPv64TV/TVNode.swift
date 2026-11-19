import Foundation
import Observation
import CloudKit
import CryptoKit
import IPv64

/// Nodes saved on this Apple TV. Stored like the iOS app's direct access (`LocalNodeStore`: URL in
/// UserDefaults, key in the Keychain) under the owner "tv"; one of them is active (dashboard, query log).
nonisolated enum TVNode {
    private static let owner = "tv"
    private static let activeKey = "TV_ACTIVE_NODE"

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    struct Saved: Identifiable, Hashable {
        let id: String
        let name: String?
        let url: String
    }

    static var saved: [Saved] {
        LocalNodeStore.list(owner: owner).map { Saved(id: $0, name: LocalNodeStore.name($0), url: LocalNodeStore.url($0) ?? "") }
    }

    /// The selected node, else the first saved one.
    static var activeId: String? {
        let ids = LocalNodeStore.list(owner: owner)
        return UserDefaults.standard.string(forKey: activeKey).flatMap { ids.contains($0) ? $0 : nil } ?? ids.first
    }

    static var url: String? { activeId.flatMap(LocalNodeStore.url) }
    static var name: String? { activeId.flatMap(LocalNodeStore.name) }

    static func client() -> Node64? {
        activeId.flatMap { LocalNodeStore.get($0, owner: owner) }.flatMap(NodeClientFactory.client(for:))
    }

    static func select(_ id: String) { UserDefaults.standard.set(id, forKey: activeKey) }

    /// Checks address and key against the node (DNS64 must answer) and saves it. A new node becomes active.
    /// `id`: the id the iPhone knows it by (iCloud tile); `replacing`: the saved node being edited (empty key keeps its key).
    static func connect(address: String, key rawKey: String, id knownId: String? = nil, replacing: String? = nil) async throws {
        let typed = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = typed.isEmpty ? (replacing.flatMap { LocalNodeStore.get($0, owner: owner)?.key } ?? "") : typed
        guard let url = LocalNodeURL.normalizeLocalNodeUrl(address),
              let client = NodeClientFactory.client(url: url, key: key) else {
            throw Failure(message: LocalNodeURL.invalidInputMessage(address))
        }
        guard !key.isEmpty else { throw Failure(message: String(localized: "Enter the node API key.")) }
        let status = try await client.node.status()
        _ = try await client.dns64.status()
        let id = knownId ?? status.node?.id?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? url
        let wasActive = replacing == nil || replacing == activeId
        try LocalNodeStore.save(id: id, url: url, key: key, owner: owner, name: status.node?.name)
        if let replacing, replacing != id { LocalNodeStore.remove(replacing) }
        if wasActive { select(id) }
    }

    /// Takes over URL, key or name of saved nodes only when the iPhone changed them since the last look,
    /// so an address or key the user set on this TV is not overwritten on every visit. `true` if anything changed.
    static func adopt(_ all: [NodeCloudStore.Node]) -> Bool {
        // One record per node: the same node can come from two ipv64.net accounts; the lowest account wins,
        // so two differing copies can't overwrite each other on every load.
        let nodes = Dictionary(grouping: all, by: \.nodeId).values.compactMap { $0.min { $0.account < $1.account } }
        let cloudIds = Set(nodes.map(\.nodeId))
        var ids = Set(LocalNodeStore.list(owner: owner))
        var changed = false
        // A node saved here under another id (manual entry without node id, early test builds) but with the same
        // address as an iPhone node moves to the iPhone's id, keeping the key entered here. Never another iPhone
        // node's entry, or two iPhone nodes with one address would swap on every load.
        for node in nodes where !ids.contains(node.nodeId) {
            guard let match = ids.first(where: { !cloudIds.contains($0) && LocalNodeStore.url($0) == node.url }),
                  let stored = LocalNodeStore.get(match, owner: owner) else { continue }
            let wasActive = activeId == match
            guard (try? LocalNodeStore.save(id: node.nodeId, url: stored.url, key: stored.key, owner: owner,
                                            name: LocalNodeStore.name(match) ?? node.name)) != nil else { continue }
            forget(match)
            if wasActive { select(node.nodeId) }
            ids.remove(match)
            ids.insert(node.nodeId)
            changed = true
        }
        for node in nodes where ids.contains(node.nodeId) {
            let seenKey = "TV_CLOUD_SEEN.\(node.nodeId)"
            let fingerprint = SHA256.hash(data: Data("\(node.url)|\(node.key)|\(node.name ?? "")".utf8)).description
            let seen = UserDefaults.standard.string(forKey: seenKey)
            UserDefaults.standard.set(fingerprint, forKey: seenKey)
            guard let seen, seen != fingerprint else { continue }
            try? LocalNodeStore.save(id: node.nodeId, url: node.url, key: node.key, owner: owner, name: node.name)
            changed = true
        }
        return changed
    }

    static func forget(_ id: String) {
        LocalNodeStore.remove(id)
        UserDefaults.standard.removeObject(forKey: "TV_CLOUD_SEEN.\(id)")
    }
}

/// Saved nodes, the active client and the iCloud list for all screens; `reload()` after any change.
@Observable final class TVSession {
    private(set) var client: Node64? = TVNode.client()
    private(set) var saved = TVNode.saved
    private(set) var activeId = TVNode.activeId
    /// Bumped on every reload so screens restart their loads for the new node.
    private(set) var generation = 0

    func reload() {
        client = TVNode.client()
        saved = TVNode.saved
        activeId = TVNode.activeId
        generation += 1
    }

    /// Nodes the iPhone app mirrored to iCloud (`NodeCloudStore`); `nil` until loaded.
    private(set) var cloudNodes: [NodeCloudStore.Node]?
    private(set) var cloudError: String?

    /// Shown as the spinner on Reload; also keeps a second fetch from starting.
    private(set) var loadingCloud = false

    /// One fetch at a time (launch and the Nodes tab both ask), so an older result can't land last.
    func loadCloudNodes() async {
        guard !loadingCloud else { return }
        loadingCloud = true
        defer { loadingCloud = false }
        do {
            let nodes = try await NodeCloudStore.fetchAll()
            cloudNodes = nodes
            cloudError = nil
            if TVNode.adopt(nodes) { reload() }
        } catch let error as CKError where error.code == .notAuthenticated {
            cloudError = String(localized: "Sign in to iCloud on this Apple TV to see the nodes of your iPhone.")
        } catch {
            cloudError = error.localizedDescription
        }
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
