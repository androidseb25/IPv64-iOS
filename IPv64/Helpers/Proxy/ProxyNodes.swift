import Foundation
import IPv64

/// Proxy hosts and CDN64 status of one connected proxy node (Android `NodeHosts` / `NodeOnline`).
struct ProxyNodeData: Identifiable {
    let id: String
    let name: String
    var hosts: [Node64.ProxyHost] = []
    var online: Node64.CDNOnlineStatus?
    /// Set when the node does not answer.
    var error: ErrorText?

    /// CDN64 names by host id.
    var cdn: [Int: Node64.CDNOnlineName] {
        Dictionary((online?.names ?? []).compactMap { n in n.hostID.map { ($0, n) } }, uniquingKeysWith: { a, _ in a })
    }
}

extension ProxyNodeData {
    /// Loads one node (`withHosts: false`: CDN64 status only, its error counts); a failure stays in `error`.
    nonisolated static func load(id: String, name: String, client: Node64?, withHosts: Bool) async -> ProxyNodeData {
        var data = ProxyNodeData(id: id, name: name)
        guard let client else {
            data.error = ErrorText(title: String(localized: "Node not reachable"),
                                   message: String(localized: "No access saved for this node."))
            return data
        }
        do {
            if withHosts {
                data.hosts = try await client.proxy64.hosts.list()
                // CDN64 is optional: a node without tunnel answers with an error.
                data.online = try? await client.proxy64.online.status()
            } else {
                data.online = try await client.proxy64.online.status()
            }
        } catch {
            data.error = ErrorText.node(error)
        }
        return data
    }
}

/// One proxy host that can still get CDN64.
struct CdnHostChoice: Identifiable, Hashable {
    let nodeId: String
    let nodeName: String
    let hostId: Int
    let label: String
    var id: String { "\(nodeId)/\(hostId)" }
}

extension ConnectedNodes {
    /// Every proxy node in parallel; a failing node affects only itself.
    func loadProxyNodes(withHosts: Bool) async -> [ProxyNodeData] {
        let jobs = proxyIds.map { ($0, name(of: $0), client(for: $0)) }
        return await withTaskGroup(of: (Int, ProxyNodeData).self) { group in
            for (index, job) in jobs.enumerated() {
                group.addTask { (index, await ProxyNodeData.load(id: job.0, name: job.1, client: job.2, withHosts: withHosts)) }
            }
            var result: [(Int, ProxyNodeData)] = []
            for await item in group { result.append(item) }
            return result.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    func loadProxyNode(_ id: String, withHosts: Bool) async -> ProxyNodeData {
        await ProxyNodeData.load(id: id, name: name(of: id), client: client(for: id), withHosts: withHosts)
    }

    /// Hosts of the given nodes that are not in CDN64 yet; nodes whose host list fails are skipped.
    func cdnChoices(for nodes: [ProxyNodeData]) async -> [CdnHostChoice] {
        var choices: [CdnHostChoice] = []
        for node in nodes where node.error == nil {
            guard let client = client(for: node.id), let hosts = try? await client.proxy64.hosts.list() else { continue }
            let used = Set(node.online?.names?.compactMap(\.hostID) ?? [])
            choices += hosts.filter { !used.contains($0.id) }.map {
                CdnHostChoice(nodeId: node.id, nodeName: node.name, hostId: $0.id,
                              label: ($0.names ?? []).joined(separator: ", ").nonBlank ?? "#\($0.id)")
            }
        }
        return choices
    }

    /// Enables CDN64 for a host; returns an error to show (also a partly failed name), `nil` on success.
    func enableCdn64(_ choice: CdnHostChoice, mode: Int, healthcheck: Bool) async -> ErrorText? {
        guard let client = client(for: choice.nodeId) else {
            return ErrorText(title: String(localized: "No access"), message: String(localized: "No access saved for this node."))
        }
        do {
            let result = try await client.proxy64.online.enable(host: choice.hostId, mode: mode, healthcheck: healthcheck)
            return ProxyLogic.firstEnableError((result.results ?? []).map { ($0.name, $0.result == .error, $0.error, $0.code) })
                .map { ErrorText(title: "CDN64", message: $0) }
        } catch {
            return ErrorText.node(error)
        }
    }
}
