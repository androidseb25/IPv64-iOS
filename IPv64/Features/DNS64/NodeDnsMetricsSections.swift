import SwiftUI
import IPv64

/// KPI tiles, chart, upstreams, cache and top lists (spec 03 §6.2 items 6–10).
struct NodeDnsMetricsSections: View {
    let data: DnsData
    let range: DnsRange
    let dns: Node64.DNS64
    let actions: DnsActions
    let onCache: (DnsSec<Node64.DNS64Cache>) -> Void

    var body: some View {
        kpiSection
        NodeDnsChartSection(timeline: data.timeline, range: range)
        NodeDnsUpstreamsSection(upstreams: data.upstreams)
        NodeDnsCacheSection(cache: data.cache, dns: dns, actions: actions, onCache: onCache)
        NodeDnsRankingSection(title: "Top blocked domains", items: data.blocked, label: { $0.name ?? "–" })
        NodeDnsRankingSection(title: "Top queried domains", items: data.allowed, label: { $0.name ?? "–" })
        NodeDnsRankingSection(title: "Top clients", items: data.clients,
                              label: { $0.hostname?.nonBlank ?? $0.name ?? "–" })
    }

    @ViewBuilder private var kpiSection: some View {
        switch data.summary {
        case .failure(let failure):
            Section("Overview") { Text(verbatim: failure.text).foregroundStyle(Color.ipv64Red) }
        case .success(let summary):
            let s = summary.summary
            let total = s?.total ?? 0
            let blocked = s?.blocked ?? 0
            let cached = s?.cached ?? 0
            Section {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        DnsKpiTile("Queries", Formatters.count(total),
                                   caption: String(localized: "≈ \(Formatters.count(dns64PerHour(total: total, hours: range.hours))) per hour"))
                        DnsKpiTile("Blocked", Formatters.count(blocked),
                                   caption: String(localized: "\(dns64Percent(blocked, of: total)) % of queries"))
                    }
                    GridRow {
                        DnsKpiTile("From cache", Formatters.count(cached),
                                   caption: String(localized: "\(dns64Percent(cached, of: total)) % answered instantly"))
                        DnsKpiTile("Clients", Formatters.count(s?.clients ?? 0), caption: nil)
                    }
                    GridRow {
                        DnsKpiTile("Ø Upstream", s?.avgUpstreamMs.map { "\(dns64Ms($0)) ms" } ?? "–", caption: nil)
                        DnsKpiTile("Blocklists", Formatters.count(summary.blocklistSize ?? 0), caption: String(localized: "domains"))
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
    }
}

/// KPI tile; stretches to the row height of its Grid row so tiles are equally tall.
private struct DnsKpiTile: View {
    let label: LocalizedStringKey
    let value: String
    let caption: String?

    init(_ label: LocalizedStringKey, _ value: String, caption: String?) {
        self.label = label
        self.value = value
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value).font(.title2.weight(.semibold)).minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.footnote).foregroundStyle(.secondary)
            if let caption { Text(verbatim: caption).font(.caption2).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct NodeDnsUpstreamsSection: View {
    let upstreams: DnsSec<Node64.DNS64Upstreams>

    var body: some View {
        Section("Upstream servers") {
            switch upstreams {
            case .failure(let failure):
                Text(verbatim: failure.text).foregroundStyle(Color.ipv64Red)
            case .success(let value):
                if let mode = value.mode { Text("Mode: \(mode.rawValue)").foregroundStyle(.secondary) }
                let servers = value.servers ?? []
                if servers.isEmpty { Text("No upstream servers.").foregroundStyle(.secondary) }
                let wins = servers.reduce(0) { $0 + ($1.wins ?? 0) }
                ForEach(servers) { server in row(server, totalWins: wins) }
            }
        }
    }

    private func row(_ s: Node64.DNS64UpstreamStats, totalWins: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: s.name ?? s.url ?? "–").font(.headline).lineLimit(2)
                Spacer(minLength: 8)
                if let proto = s.proto { StatusChip(verbatim: proto.rawValue.uppercased(), color: .ipv64Gray) }
                StatusChip(s.healthy == true ? "Healthy" : "Unhealthy", color: s.healthy == true ? .ipv64Green : .ipv64Red)
                if s.active == true { StatusChip("Active", color: .ipv64Green) }
            }
            Text("Ø \(dns64Ms(s.avgMs)) ms · fastest at \(dns64Percent(s.wins ?? 0, of: s.requests ?? 0)) % · \(Formatters.count(s.requests ?? 0)) queries · \(s.errors ?? 0) errors")
                .font(.footnote).foregroundStyle(.secondary)
            ProgressView(value: totalWins > 0 ? Double(s.wins ?? 0) / Double(totalWins) : 0)
            if let error = s.lastError?.nonBlank {
                Text(verbatim: error).font(.footnote).foregroundStyle(Color.ipv64Red)
            }
        }
    }
}

private struct NodeDnsCacheSection: View {
    let cache: DnsSec<Node64.DNS64Cache>
    let dns: Node64.DNS64
    let actions: DnsActions
    let onCache: (DnsSec<Node64.DNS64Cache>) -> Void

    @State private var confirm: ConfirmRequest?

    var body: some View {
        Section("DNS cache") {
            switch cache {
            case .failure(let failure):
                Text(verbatim: failure.text).foregroundStyle(Color.ipv64Red)
            case .success(let c):
                let hits = c.hits ?? 0
                let lookups = hits + (c.misses ?? 0)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hit rate \(dns64Percent(hits, of: lookups)) %")
                    ProgressView(value: lookups > 0 ? Double(hits) / Double(lookups) : 0)
                }
                LabeledContent("Entries", value: String(localized: "\(Formatters.count(c.entries ?? 0)) of \(Formatters.count(c.max ?? 0))"))
                LabeledContent("Stale served", value: Formatters.count(c.staleServed ?? 0))
                LabeledContent("Refreshed in background", value: Formatters.count(c.refreshed ?? 0))
                Button("Flush cache", systemImage: "trash", role: .destructive) { ask() }
                    .disabled(actions.isBusy)
            }
        }
        .confirmDialog($confirm)
    }

    private func ask() {
        confirm = ConfirmRequest(
            title: String(localized: "Flush cache"),
            message: String(localized: "Remove all cached DNS answers on this node? The next queries are answered by the upstream servers."),
            confirmLabel: String(localized: "Flush"), destructive: true) {
            Task {
                await actions.run("Flushing cache...") {
                    _ = try await dns.cache.flush()
                    onCache(await dnsSec { try await dns.cache.get() })
                }
            }
        }
    }
}

private struct NodeDnsRankingSection: View {
    let title: LocalizedStringKey
    let items: DnsSec<[Node64.DNS64TopItem]>
    let label: (Node64.DNS64TopItem) -> String

    var body: some View {
        Section(title) {
            switch items {
            case .failure(let failure):
                Text(verbatim: failure.text).foregroundStyle(Color.ipv64Red)
            case .success(let list):
                if list.isEmpty { Text("No data").foregroundStyle(.secondary) }
                let maxCount = max(list.map { $0.count ?? 0 }.max() ?? 0, 1)
                ForEach(Array(list.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(verbatim: label(item)).lineLimit(2).truncationMode(.tail)
                            Spacer(minLength: 8)
                            Text(verbatim: Formatters.count(item.count ?? 0)).foregroundStyle(.secondary).monospacedDigit()
                        }
                        ProgressView(value: max(Double(item.count ?? 0) / Double(maxCount), 0.02))
                    }
                }
            }
        }
    }
}
