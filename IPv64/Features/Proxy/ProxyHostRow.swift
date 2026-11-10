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
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: (host.names ?? []).joined(separator: ", ").nonBlank ?? "–").font(.headline)
            if !subtitle.isEmpty { Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary) }
            ChipFlow(spacing: 6) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    StatusChip(verbatim: chip.text, color: chip.color.color)
                }
            }
            if let line = ProxyLogic.counterLine(requests: host.stats?.requests, errors: host.stats?.errors, blocked: host.stats?.blocked) {
                Text(verbatim: line).font(.caption).foregroundStyle(.secondary)
            }
            if let error = (host.routeError ?? host.certificateError)?.nonBlank {
                Text(verbatim: error).font(.caption).foregroundStyle(Color.ipv64Red)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Wrapping row of chips.
struct ChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(bounds.width, subviews)
        for (subview, origin) in zip(subviews, result.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func layout(_ width: CGFloat, _ subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + 4; rowHeight = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}
