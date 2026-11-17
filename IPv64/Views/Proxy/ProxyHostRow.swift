import SwiftUI
import IPv64

/// Proxy host row: names bold, target secondary, reachability tag trailing, SSL and CDN64 tags below,
/// options and counters as one secondary line.
struct ProxyHostRow: View {
    let host: Node64.ProxyHost
    let cdn: Node64.CDNOnlineName?
    var edges: [Node64.CDNOnlineEdge] = []

    private var reach: ProxyLogic.Tag {
        ProxyLogic.reachTag(enabled: host.enabled, state: host.reach?.state?.rawValue, ms: host.reach?.ms)
    }

    private var extraTags: [ProxyLogic.Tag] {
        var list: [ProxyLogic.Tag] = []
        if let ssl = ProxyLogic.sslTag(state: host.certificate?.state?.rawValue, daysLeft: host.certificate?.daysLeft) {
            list.append(ssl)
        }
        if let cdn {
            list.append(ProxyLogic.cdnTag(mode: cdn.mode, edgeCount: edges.count, up: edges.filter { $0.connected == true }.count))
        }
        return list
    }

    private var subtitle: String {
        ProxyLogic.hostSubtitle(kind: host.kind?.rawValue, scheme: host.scheme?.rawValue, targetHost: host.targetHost,
                                targetPort: host.targetPort, redirectTarget: host.redirectTarget)
    }

    private var detailLine: String? {
        let options = ProxyLogic.optionsLine(
            websockets: host.websockets, blockExploits: host.blockExploits, cacheAssets: host.cacheAssets,
            forceSSL: host.forceSSL, http2: host.http2, http3: host.http3, hsts: host.hsts, accessListID: host.accessListID)
        let counters = ProxyLogic.counterLine(requests: host.stats?.requests, errors: host.stats?.errors, blocked: host.stats?.blocked)
        let line = [options, counters].compactMap { $0 }.joined(separator: " · ")
        return line.isEmpty ? nil : line
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: (host.names ?? []).joined(separator: ", ").nonBlank ?? "–").font(.headline).lineLimit(2)
                    if !subtitle.isEmpty {
                        Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ProxyTag(tag: reach)
            }
            if !extraTags.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { ForEach(extraTags, id: \.text) { ProxyTag(tag: $0) } }
                    VStack(alignment: .leading, spacing: 4) { ForEach(extraTags, id: \.text) { ProxyTag(tag: $0) } }
                }
            }
            if let detailLine {
                Text(verbatim: detailLine).font(.caption).foregroundStyle(.secondary)
            }
            if let error = (host.routeError ?? host.certificateError)?.nonBlank {
                Text(verbatim: error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Capsule tag in the style of the other lists.
struct ProxyTag: View {
    let tag: ProxyLogic.Tag

    private var color: Color {
        switch tag.tone {
        case .gray: .gray
        case .green: .green
        case .orange: .orange
        case .red: .red
        }
    }

    var body: some View {
        Text(verbatim: tag.text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .fixedSize()
    }
}
