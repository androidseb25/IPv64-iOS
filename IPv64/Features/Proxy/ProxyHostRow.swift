import SwiftUI
import IPv64

/// Host row (spec 03 §3.3): names, target, status capsules, counters, errors. Also the header of the editor.
struct ProxyHostRow: View {
    let host: Node64.ProxyHost
    let cdn: Node64.CDNOnlineName?
    var edges: [Node64.CDNOnlineEdge] = []

    private var chips: [ProxyLogic.Chip] {
        var list = [ProxyLogic.reachChip(enabled: host.enabled, state: host.reach?.state?.rawValue, ms: host.reach?.ms)]
        if let ssl = ProxyLogic.sslChip(state: host.certificate?.state?.rawValue, daysLeft: host.certificate?.daysLeft) {
            list.append(ssl)
        }
        if let cdn {
            list.append(ProxyLogic.cdnChip(mode: cdn.mode, edgeCount: edges.count, up: edges.filter { $0.connected == true }.count))
        }
        list += ProxyLogic.optionChips(
            websockets: host.websockets, blockExploits: host.blockExploits, cacheAssets: host.cacheAssets,
            forceSSL: host.forceSSL, http2: host.http2, http3: host.http3, hsts: host.hsts,
            accessListID: host.accessListID).map { ProxyLogic.Chip(text: $0, color: .gray) }
        return list
    }

    private var subtitle: String {
        ProxyLogic.hostSubtitle(kind: host.kind?.rawValue, scheme: host.scheme?.rawValue, targetHost: host.targetHost,
                                targetPort: host.targetPort, redirectTarget: host.redirectTarget)
    }

    var body: some View {
        // 2.0 look: status dot and plain text lines instead of chip rows.
        let status = chips.prefix(1) + chips.dropFirst().filter { $0.color != .gray }
        let options = chips.dropFirst().filter { $0.color == .gray }.map(\.text)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().fill(chips.first?.color.color ?? .ipv64Gray).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: (host.names ?? []).joined(separator: ", ").nonBlank ?? "–").font(.headline)
                if !subtitle.isEmpty { Text(verbatim: subtitle).font(.subheadline) }
                ForEach(Array(status.enumerated()), id: \.offset) { _, chip in
                    Text(verbatim: chip.text).font(.caption).foregroundStyle(chip.color.color)
                }
                if !options.isEmpty {
                    Text(verbatim: options.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                }
                if let line = ProxyLogic.counterLine(requests: host.stats?.requests, errors: host.stats?.errors, blocked: host.stats?.blocked) {
                    Text(verbatim: line).font(.caption).foregroundStyle(.secondary)
                }
                if let error = (host.routeError ?? host.certificateError)?.nonBlank {
                    Text(verbatim: error).font(.caption).foregroundStyle(Color.ipv64Red)
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
