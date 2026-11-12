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
            // One list section like the Fitness/Health summaries: values in two columns, no separate cards.
            Section("Overview") {
                Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        DnsKpiTile("Queries", total.formatted(), caption: String(localized: "≈ \((total / range.hours).formatted()) per hour"))
                        DnsKpiTile("Blocked", blocked.formatted(), caption: String(localized: "\(dns64Percent(blocked, of: total)) % of queries"))
                    }
                    Divider()
                    GridRow {
                        DnsKpiTile("From cache", cached.formatted(), caption: String(localized: "\(dns64Percent(cached, of: total)) % answered instantly"))
                        DnsKpiTile("Clients", (s?.clients ?? 0).formatted(), caption: nil)
                    }
                    Divider()
                    GridRow {
                        DnsKpiTile("Ø Upstream", s?.avgUpstreamMs.map { "\(dns64Ms($0)) ms" } ?? "–", caption: nil)
                        DnsKpiTile("Blocklists", (summary.blocklistSize ?? 0).formatted(), caption: String(localized: "domains"))
                    }
                }
                .padding(.vertical, 4)
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
            Text(verbatim: value).font(.system(.title2, design: .rounded).weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
            if let caption { Text(verbatim: caption).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

/// Stacked Allowed/Blocked bars on a time axis; touching a bar shows its time and counts above the chart.
/// Each bar spans its bucket (start → next start), so the width is right for any bucket size.
private struct DnsQueriesChart: View {
    let bars: [Dns64Bar]
    let range: DnsRange
    @State private var rawSelection: Date?

    private struct Span: Identifiable {
        let bar: Dns64Bar
        let start: Date
        let end: Date
        var id: Int { bar.index }
    }

    /// Bars with a time; the last bucket gets the same length as the one before.
    private var spans: [Span] {
        let dated = bars.compactMap { bar in bar.start.map { (bar, $0) } }
        return dated.indices.map { i in
            let (bar, start) = dated[i]
            let step = i + 1 < dated.count ? dated[i + 1].1.timeIntervalSince(start)
                : (i > 0 ? start.timeIntervalSince(dated[i - 1].1) : 3600)
            return Span(bar: bar, start: start, end: start.addingTimeInterval(step * 0.85))
        }
    }

    private var maxValue: Int { max(bars.map { $0.allowed + $0.blocked }.max() ?? 0, 1) }

    private var selected: Span? {
        guard let raw = rawSelection else { return nil }
        return spans.first { raw >= $0.start && raw < $0.end }
            ?? spans.min { abs($0.start.timeIntervalSince(raw)) < abs($1.start.timeIntervalSince(raw)) }
    }

    private var header: Text {
        guard let span = selected else { return Text("Touch the chart for values") }
        let when = dns64Format(span.start, .dayMonthHm)
        return Text("\(when)  Allowed: \(span.bar.allowed.formatted())  Blocked: \(span.bar.blocked.formatted())")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header.font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            Chart(spans) { span in
                RectangleMark(xStart: .value("Start", span.start), xEnd: .value("End", span.end),
                        yStart: .value("Queries", 0), yEnd: .value("Queries", span.bar.allowed))
                    .foregroundStyle(Color.green.opacity(opacity(span)))
                RectangleMark(xStart: .value("Start", span.start), xEnd: .value("End", span.end),
                        yStart: .value("Queries", span.bar.allowed),
                        yEnd: .value("Queries", span.bar.allowed + span.bar.blocked))
                    .foregroundStyle(Color.red.opacity(opacity(span)))
            }
            .chartYScale(domain: 0...maxValue)
            .chartXSelection(value: $rawSelection)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(verbatim: dns64Format(date, range == .week ? .dayMonth : .hm))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel()
                }
            }
            .frame(height: 160)
            .accessibilityLabel("Stacked bar chart with \(bars.count) bars, maximum \(maxValue.formatted())")
            HStack(spacing: 12) {
                legend("Allowed", .green)
                legend("Blocked", .red)
                Spacer()
                Text("max \(maxValue.formatted())")
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .onChange(of: bars) { rawSelection = nil }
    }

    private func opacity(_ span: Span) -> Double { selected == nil || selected?.id == span.id ? 1 : 0.35 }

    private func legend(_ text: LocalizedStringKey, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}
