import Foundation
import Observation
import IPv64

/// Nodes of the active account with stored direct access (Android `ConnectedNodes`, spec 01 §5.8).
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

    private let session: Session

    init(session: Session) {
        self.session = session
        refresh()
    }

    /// `LocalNodeStore` owner of the active account (`Account.id.uuidString`, "" when none).
    var owner: String { session.accounts.current?.id.uuidString ?? "" }

    /// Stored access of a node of the active account.
    func access(for nodeId: String) -> LocalNodeStore.Access? { LocalNodeStore.get(nodeId, owner: owner) }

    /// Node64 client for a connected node, `nil` without stored access.
    func client(for nodeId: String) -> Node64? { access(for: nodeId).flatMap(NodeClientFactory.client(for:)) }

    /// Display name: stored name, else "Node …" + last 4 chars.
    func name(of nodeId: String) -> String { Formatters.nodeName(LocalNodeStore.name(nodeId), nodeId: nodeId) }

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

#if DEBUG
extension ConnectedNodes {
    /// Mock smoke tests: `-MOCK_NODES http://localhost:8064/node/api,http://localhost:8064/node2/api` connects
    /// these nodes directly (any key) for the active account, so node features can be checked without typing.
    func connectMockNodes() async {
        guard AppConfig.mockBase != nil, session.isLoggedIn,
              let raw = UserDefaults.standard.string(forKey: "MOCK_NODES") else { return }
        for input in raw.split(separator: ",") {
            guard let url = LocalNodeURL.normalizeLocalNodeUrl(String(input)),
                  let client = NodeClientFactory.client(url: url, key: "node64_mock"),
                  let status = try? await client.node.status(),
                  let id = status.node?.id, !id.isEmpty else { continue }
            try? LocalNodeStore.save(id: id, url: url, key: "node64_mock", owner: owner, name: status.node?.name)
            if let modules = status.modules { LocalNodeStore.saveModules(id, modules: modules) }
        }
        refresh()
    }
}
#endif
