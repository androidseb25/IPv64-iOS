import SwiftUI
import Foundation
import IPv64

/// CDN64 status of one connected proxy node (Android `NodeOnline`).
struct NodeOnline: Identifiable {
    let id: String
    let name: String
    let status: Node64.CDNOnlineStatus?
    let error: String?

    /// Hosts that run through CDN64, by host id.
    var cdn: [Int: Node64.CDNOnlineName] {
        Dictionary((status?.names ?? []).compactMap { n in n.hostID.map { ($0, n) } }, uniquingKeysWith: { a, _ in a })
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

/// Android `ConnectedNodes.nodeOf` + `loadNodeOnline`, `enableCdn64`.
extension ConnectedNodes {
    /// `online.status()` of every proxy node in parallel; a failing node affects only itself.
    func loadNodeOnline() async -> [NodeOnline] {
        let jobs = proxyIds.map { ($0, name(of: $0), client(for: $0)) }
        return await withTaskGroup(of: (Int, NodeOnline).self) { group in
            for (index, job) in jobs.enumerated() {
                group.addTask {
                    let (id, name, client) = job
                    guard let client else {
                        return (index, NodeOnline(id: id, name: name, status: nil, error: "No access saved for this node."))
                    }
                    do {
                        return (index, NodeOnline(id: id, name: name, status: try await client.proxy64.online.status(), error: nil))
                    } catch {
                        return (index, NodeOnline(id: id, name: name, status: nil, error: ErrorText.node(error).titledText))
                    }
                }
            }
            var result: [(Int, NodeOnline)] = []
            for await item in group { result.append(item) }
            return result.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// Hosts of the given nodes that are not in CDN64 yet; nodes whose host list fails are skipped.
    func cdnChoices(for nodes: [(id: String, name: String, used: Set<Int>)]) async -> [CdnHostChoice] {
        var choices: [CdnHostChoice] = []
        for node in nodes {
            guard let client = client(for: node.id), let hosts = try? await client.proxy64.hosts.list() else { continue }
            choices += hosts.filter { !node.used.contains($0.id) }.map {
                CdnHostChoice(nodeId: node.id, nodeName: node.name, hostId: $0.id,
                              label: ($0.names ?? []).joined(separator: ", ").nonBlank ?? "#\($0.id)")
            }
        }
        return choices
    }
}

extension Node64 {
    /// Enables CDN64 for a host; returns the error text of the first failed name or `nil`.
    func enableCdn64(host: Int, mode: Int, healthcheck: Bool) async throws -> String? {
        let result = try await proxy64.online.enable(host: host, mode: mode, healthcheck: healthcheck)
        return ProxyLogic.firstEnableError((result.results ?? []).map {
            ($0.name, $0.result == .error, $0.error, $0.code)
        })
    }
}

/// Cancellation (leaving the screen) must never show an error.
nonisolated func isCancellation(_ error: any Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
}

extension ProxyLogic.ChipColor {
    var color: Color {
        switch self {
        case .gray: .ipv64Gray
        case .green: .ipv64Green
        case .orange: .ipv64Orange
        case .red: .ipv64Red
        case .blue: .ipv64Blue
        }
    }
}
