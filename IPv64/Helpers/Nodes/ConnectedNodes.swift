import Foundation
import Observation
import IPv64

/// Nodes of the active account with stored direct access (Android `ConnectedNodes`).
/// Drives the CDN64/Proxy64 tab and the DNS64 tab. Injected with `.environment(nodes)`.
@Observable
final class ConnectedNodes {
    /// Sorted node ids with stored access for the active account.
    private(set) var ids: [String] = []
    /// Subset whose last known status has the proxy module enabled.
    private(set) var proxyIds: [String] = []
    /// Subset whose last known status has DNS64 enabled.
    private(set) var dnsIds: [String] = []

    var proxyActive: Bool { !proxyIds.isEmpty }

    init() { refresh() }

    /// `LocalNodeStore` owner of the active account (`User.uuid`, "" when none).
    var owner: String { User.empty.current?.uuid ?? "" }

    /// Stored access of a node of the active account.
    func access(for nodeId: String) -> LocalNodeStore.Access? { LocalNodeStore.get(nodeId, owner: owner) }

    /// Node64 client for a connected node, `nil` without stored access.
    func client(for nodeId: String) -> Node64? { access(for: nodeId).flatMap(NodeClientFactory.client(for:)) }

    /// Display name: stored name, else "Node …" + last 4 chars.
    func name(of nodeId: String) -> String { NodesLogic.nodeName(LocalNodeStore.name(nodeId), nodeId: nodeId) }

    /// Stable ipv64.net account id that scopes the iCloud node sync; `nil` while sync is off or the id is
    /// not known yet (`PushRegistrar.ensureAccountId`) — never the per-device `User.uuid`.
    private var syncAccount: Int? {
        guard NodeSyncStore.isEnabled, !owner.isEmpty,
              let keyHash = PushSetupStore.keyHash(apiKey: UserStorage.shared.ApiKey) else { return nil }
        return PushSetupStore.accountId(keyHash: keyHash)
    }

    /// Writes a saved or renamed access to the iCloud Keychain.
    func push(_ nodeId: String) {
        guard let account = syncAccount else { return }
        NodeSyncStore.push(nodeId, account: account, owner: owner)
    }

    /// "Forget access": removes it here and on the user's other devices. Without a known account id yet,
    /// the deletion waits in `pendingDeletes` for the next sync.
    func forget(_ nodeId: String) {
        LocalNodeStore.remove(nodeId)
        if let account = syncAccount, NodeSyncStore.delete(nodeId, account: account) { return }
        // Queued even if never synced here: another device may already have pushed it.
        if let scope = pendingScope { pendingDeletes.append("\(scope)|\(nodeId)") }
    }

    /// Pending deletes are tied to the API key they were made with, so another account never applies them.
    private var pendingScope: String? { PushSetupStore.keyHash(apiKey: UserStorage.shared.ApiKey) }

    private var pendingDeletes: [String] {
        get { UserDefaults(suiteName: AppConfig.appGroup)?.stringArray(forKey: "NODE64_SYNC_PENDING_DELETE") ?? [] }
        set { UserDefaults(suiteName: AppConfig.appGroup)?.set(newValue, forKey: "NODE64_SYNC_PENDING_DELETE") }
    }

    /// Writes the deletion markers queued for the current account; failed ones stay queued.
    private func flushPendingDeletes(account: Int) {
        guard let scope = pendingScope else { return }
        pendingDeletes = pendingDeletes.filter { item in
            let parts = item.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == scope else { return true }
            return !NodeSyncStore.delete(parts[1], account: account)
        }
    }
    @ObservationIgnored private var lastSync: Date?

    /// Two-way iCloud sync, then re-reads the store. Without `force`, at most every 30 s (every activation
    /// calls it, also after Face ID or Control Center).
    func syncWithCloud(force: Bool = false) {
        guard let account = syncAccount else { return }
        if !force, let lastSync, Date.now.timeIntervalSince(lastSync) < 30 { return }
        lastSync = .now
        flushPendingDeletes(account: account)
        NodeSyncStore.sync(account: account, owner: owner)
        refresh()
    }

    /// Re-reads the store (no network); arrays change only when their content does.
    func refresh() {
        let list = LocalNodeStore.list(owner: owner)
        let proxy = list.filter(LocalNodeStore.proxyActive)
        let dns = list.filter(LocalNodeStore.dnsActive)
        if list != ids { ids = list }
        if proxy != proxyIds { proxyIds = proxy }
        if dns != dnsIds { dnsIds = dns }
    }

    /// Asks every connected node for its modules in parallel; unreachable nodes keep their last state.
    func refreshModules() async {
        let clients = ids.compactMap { id in client(for: id).map { (id, $0) } }
        await withTaskGroup(of: Void.self) { group in
            for (id, client) in clients {
                group.addTask {
                    guard let modules = try? await client.node.status().modules else { return }
                    LocalNodeStore.saveModules(id, modules: modules)
                }
            }
        }
        refresh()
    }
}
