import SwiftUI
import Charts
import IPv64

/// KPI tiles, chart, upstreams, cache and top lists. Failed or empty sections stay hidden (failures show their text).
struct NodeDnsMetricsSections: View {
    let data: DnsData
    let range: DnsRange
    let dns: Node64.DNS64
    let actions: DnsActions
    let onCache: (DnsSec<Node64.DNS64Cache>) -> Void

    @State private var confirmFlush = false

    var body: some View {
        kpiSection
        chartSection
        upstreamsSection
        cacheSection
        topSection("Top blocked domains", data.blocked) { $0.name ?? "–" }
        topSection("Top queried domains", data.allowed) { $0.name ?? "–" }
        topSection("Top clients", data.clients) { $0.hostname?.nonBlank ?? $0.name ?? "–" }
    }

    @ViewBuilder private func failed(_ title: LocalizedStringKey, _ failure: DnsSectionError) -> some View {
        Section(title) { Text(verbatim: failure.text).foregroundStyle(.red) }
    }

    // MARK: KPI

    @ViewBuilder private var kpiSection: some View {
        switch data.summary {
        case .failure(let failure):
            failed("Overview", failure)
        case .success(let summary):
            let s = summary.summary
            let total = s?.total ?? 0, blocked = s?.blocked ?? 0, cached = s?.cached ?? 0
            Section {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        DnsKpiTile("Queries", total.formatted(), caption: String(localized: "≈ \((total / range.hours).formatted()) per hour"))
                        DnsKpiTile("Blocked", blocked.formatted(), caption: String(localized: "\(dns64Percent(blocked, of: total)) % of queries"))
                    }
                    GridRow {
                        DnsKpiTile("From cache", cached.formatted(), caption: String(localized: "\(dns64Percent(cached, of: total)) % answered instantly"))
                        DnsKpiTile("Clients", (s?.clients ?? 0).formatted(), caption: nil)
                    }
                    GridRow {
                        DnsKpiTile("Ø Upstream", s?.avgUpstreamMs.map { "\(dns64Ms($0)) ms" } ?? "–", caption: nil)
                        DnsKpiTile("Blocklists", (summary.blocklistSize ?? 0).formatted(), caption: String(localized: "domains"))
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: Chart

    @ViewBuilder private var chartSection: some View {
        switch data.timeline {
        case .failure(let failure):
            failed("Queries over time", failure)
        case .success(let value):
            let bars = dns64Bars(value.buckets ?? [])
            if !bars.isEmpty { Section("Queries over time") { DnsQueriesChart(bars: bars, range: range) } }
        }
    }

    // MARK: Upstreams

    @ViewBuilder private var upstreamsSection: some View {
        switch data.upstreams {
        case .failure(let failure):
            failed("Upstream servers", failure)
        case .success(let value):
            let servers = value.servers ?? []
            if !servers.isEmpty {
                let wins = servers.reduce(0) { $0 + ($1.wins ?? 0) }
                Section("Upstream servers") {
                    if let mode = value.mode { Text("Mode: \(mode.rawValue)").foregroundStyle(.secondary) }
                    ForEach(servers) { upstreamRow($0, totalWins: wins) }
                }
            }
        }
    }

    private func upstreamRow(_ s: Node64.DNS64UpstreamStats, totalWins: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: s.name ?? s.url ?? "–").font(.headline).lineLimit(2)
                Spacer(minLength: 8)
                ProxyTag(tag: .init(text: s.healthy == true ? String(localized: "Healthy") : String(localized: "Unhealthy"),
                                    tone: s.healthy == true ? .green : .red))
                if s.active == true { ProxyTag(tag: .init(text: String(localized: "Active"), tone: .green)) }
            }
            Text("Ø \(dns64Ms(s.avgMs)) ms · \((s.requests ?? 0).formatted()) queries · \(s.errors ?? 0) errors")
                .font(.footnote).foregroundStyle(.secondary)
            ProgressView(value: totalWins > 0 ? Double(s.wins ?? 0) / Double(totalWins) : 0).tint(.orange)
            if let error = s.lastError?.nonBlank { Text(verbatim: error).font(.footnote).foregroundStyle(.red) }
        }
    }

    // MARK: Cache

    @ViewBuilder private var cacheSection: some View {
        switch data.cache {
        case .failure(let failure):
            failed("DNS cache", failure)
        case .success(let c):
            let hits = c.hits ?? 0
            let lookups = hits + (c.misses ?? 0)
            Section("DNS cache") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hit rate \(dns64Percent(hits, of: lookups)) %")
                    ProgressView(value: lookups > 0 ? Double(hits) / Double(lookups) : 0).tint(.orange)
                }
                LabeledContent("Entries", value: String(localized: "\((c.entries ?? 0).formatted()) of \((c.max ?? 0).formatted())"))
                LabeledContent("Stale served", value: (c.staleServed ?? 0).formatted())
                LabeledContent("Refreshed in background", value: (c.refreshed ?? 0).formatted())
                Button("Flush cache", systemImage: "trash", role: .destructive) { confirmFlush = true }
                    .alert("Flush cache", isPresented: $confirmFlush) {
                        Button("Flush", role: .destructive) { flush() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Remove all cached DNS answers on this node? The next queries are answered by the upstream servers.")
                    }
            }
        }
    }

    private func flush() {
        Task {
            await actions.run {
                _ = try await dns.cache.flush()
                onCache(await dnsSec { try await dns.cache.get() })
            }
        }
    }

    // MARK: Top lists

    @ViewBuilder private func topSection(_ title: LocalizedStringKey, _ items: DnsSec<[Node64.DNS64TopItem]>,
                                         label: @escaping (Node64.DNS64TopItem) -> String) -> some View {
        switch items {
        case .failure(let failure):
            failed(title, failure)
        case .success(let list) where !list.isEmpty:
            let maxValue = list.compactMap(\.count).max() ?? 0
            Section(title) {
                ForEach(list.indices, id: \.self) { i in
                    let count = list[i].count ?? 0
                    ModuleRankRow(label: label(list[i]), value: count, detail: count.formatted(), maxValue: maxValue, mono: true)
                }
            }
        case .success:
            EmptyView()
        }
    }
}

/// KPI tile with a prominent number; stretches to the (equal) height of its grid row.
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
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Text(verbatim: value).font(.system(size: 32, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.5)
            Text(verbatim: caption ?? " ").font(.caption).foregroundStyle(.secondary).lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

/// Stacked Allowed/Blocked bars; touching a bar shows its time and counts above the chart.
private struct DnsQueriesChart: View {
    let bars: [Dns64Bar]
    let range: DnsRange
    @State private var selected: Int?

    private var maxValue: Int { max(bars.map { $0.allowed + $0.blocked }.max() ?? 0, 1) }

    private func axisLabel(_ bar: Dns64Bar) -> String {
        bar.start.map { dns64Format($0, range == .week ? .dayMonth : .hm) } ?? ""
    }

    private var header: Text {
        guard let i = selected, bars.indices.contains(i) else { return Text("Touch the chart for values") }
        let bar = bars[i]
        let when = bar.start.map { dns64Format($0, .dayMonthHm) } ?? ""
        return Text("\(when)  Allowed: \(bar.allowed.formatted())  Blocked: \(bar.blocked.formatted())")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header.font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            Chart {
                ForEach(bars) { bar in
                    BarMark(x: .value("Time", bar.index), y: .value("Queries", bar.allowed), width: .ratio(0.8))
                        .foregroundStyle(by: .value("Type", "Allowed")).opacity(opacity(bar))
                    BarMark(x: .value("Time", bar.index), y: .value("Queries", bar.blocked), width: .ratio(0.8))
                        .foregroundStyle(by: .value("Type", "Blocked")).opacity(opacity(bar))
                }
            }
            .chartForegroundStyleScale(["Allowed": Color.green, "Blocked": Color.red])
            .chartLegend(.hidden)
            .chartXScale(domain: -0.5...(Double(bars.count) - 0.5))
            .chartYScale(domain: 0...maxValue)
            .chartXSelection(value: $selected)
            .chartXAxis {
                AxisMarks(values: dns64AxisIndices(count: bars.count)) { value in
                    AxisValueLabel {
                        if let i = value.as(Int.self), bars.indices.contains(i) { Text(verbatim: axisLabel(bars[i])) }
                    }
                }
            }
            .chartYAxis { AxisMarks(values: [0, maxValue / 2, maxValue]) { AxisGridLine() } }
            .frame(height: 140)
            .accessibilityLabel("Stacked bar chart with \(bars.count) bars, maximum \(maxValue.formatted())")
            HStack(spacing: 12) {
                legend("Allowed", .green)
                legend("Blocked", .red)
                Spacer()
                Text("max \(maxValue.formatted())")
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .onChange(of: bars) { selected = nil }
    }

    private func opacity(_ bar: Dns64Bar) -> Double { selected == nil || selected == bar.index ? 1 : 0.4 }

    private func legend(_ text: LocalizedStringKey, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}
