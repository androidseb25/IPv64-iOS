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

extension ConnectedNodes {
    /// Hosts and CDN64 status of every proxy node in parallel (`withHosts: false`: CDN64 status only, its
    /// error counts); a failing node affects only itself.
    func loadProxyNodes(withHosts: Bool) async -> [ProxyNodeData] {
        let jobs = proxyIds.map { ($0, name(of: $0), client(for: $0)) }
        return await withTaskGroup(of: (Int, ProxyNodeData).self) { group in
            for (index, job) in jobs.enumerated() {
                group.addTask {
                    let (id, name, client) = job
                    var data = ProxyNodeData(id: id, name: name)
                    guard let client else {
                        data.error = ErrorText(title: String(localized: "Node not reachable"),
                                               message: String(localized: "No access saved for this node."))
                        return (index, data)
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
                    return (index, data)
                }
            }
            var result: [(Int, ProxyNodeData)] = []
            for await item in group { result.append(item) }
            return result.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
