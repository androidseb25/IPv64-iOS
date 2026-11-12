import Foundation
import WidgetKit
import AppIntents
import SwiftUI
import Charts
import IPv64

struct DNS64Entry: TimelineEntry {
    enum Status {
        /// The widget account has no directly connected node with DNS64.
        case noNode
        case unreachable
        /// `pausedUntil` nil while paused = until resumed.
        case loaded(paused: Bool, pausedUntil: Date?, queries: Int?, blocked: Int?)
    }

    /// One timeline bucket of the last 24 h; Allowed = max(total - blocked, 0) as in the app's `dns64Bars`.
    struct Bar: Identifiable {
        let index: Int
        let allowed: Int
        let blocked: Int
        var id: Int { index }
    }

    let date: Date
    let node: DNS64NodeEntity?
    let status: Status
    /// Empty = no chart (small size, or the timeline request failed).
    var bars: [Bar] = []

    static let sampleBars = (0..<48).map { i in Bar(index: i, allowed: 200 + (i * 37) % 180, blocked: 20 + (i * 13) % 60) }
}

struct DNS64Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DNS64Entry {
        DNS64Entry(date: .now, node: DNS64NodeEntity(id: "preview", name: "Node64"),
                   status: .loaded(paused: false, pausedUntil: nil, queries: 12_345, blocked: 1_234),
                   bars: context.family == .systemSmall ? [] : DNS64Entry.sampleBars)
    }

    func snapshot(for configuration: DNS64WidgetIntent, in context: Context) async -> DNS64Entry {
        context.isPreview ? placeholder(in: context) : await load(configuration, chart: context.family != .systemSmall)
    }

    func timeline(for configuration: DNS64WidgetIntent, in context: Context) async -> Timeline<DNS64Entry> {
        let entry = await load(configuration, chart: context.family != .systemSmall)
        var next = Date.now.addingTimeInterval(15 * 60)
        // A timed pause ends on the node by itself; refresh right after it.
        if case .loaded(true, let until?, _, _) = entry.status, until < next { next = until.addingTimeInterval(5) }
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func load(_ configuration: DNS64WidgetIntent, chart: Bool) async -> DNS64Entry {
        guard let resolved = DNS64Nodes.resolve(configuration.node?.id) else {
            return DNS64Entry(date: .now, node: nil, status: .noNode)
        }
        let dns = resolved.client.dns64
        async let status = try? dns.status()
        // The counters are optional decoration; the blocking state decides reachability.
        async let summary = try? dns.summary()
        async let timeline: Node64.DNS64Timeline? = chart ? (try? await dns.timeline(range: .last24Hours)) : nil
        guard let blocking = await status.map(\.blocking) else {
            return DNS64Entry(date: .now, node: resolved.node, status: .unreachable)
        }
        let totals = await summary?.summary
        let bars = (await timeline?.buckets ?? []).enumerated().map { i, bucket in
            let blocked = bucket.blocked ?? 0
            return DNS64Entry.Bar(index: i, allowed: max((bucket.total ?? 0) - blocked, 0), blocked: blocked)
        }
        let paused = blocking?.paused == true
        // Go zero dates count as "no date" (like `HcFormat.real` in the app).
        let until = blocking?.untilResumed == true ? nil : blocking?.pausedUntil.flatMap { $0.timeIntervalSince1970 > 0 ? $0 : nil }
        return DNS64Entry(date: .now, node: resolved.node,
                          status: .loaded(paused: paused, pausedUntil: paused ? until : nil,
                                          queries: totals?.total, blocked: totals?.blocked),
                          bars: bars)
    }
}

struct DNS64WidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: DNS64Entry

    /// Blocking state when loaded, `nil` without node data (no buttons then).
    private var paused: Bool? {
        if case .loaded(let paused, _, _, _) = entry.status { return paused }
        return nil
    }

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemLarge:
                VStack(alignment: .leading, spacing: 10) {
                    info
                    chart
                    if let paused { buttons(paused: paused) }
                }
            case .systemMedium:
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        info
                        chart
                    }
                    if let paused { buttons(paused: paused) }
                }
            default:
                VStack(alignment: .leading, spacing: 0) {
                    info
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    /// Fills the remaining height; nothing when there are no bars.
    @ViewBuilder private var chart: some View {
        if entry.bars.isEmpty {
            Spacer(minLength: 0)
        } else {
            DNS64QueriesChart(bars: entry.bars)
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("DNS64", systemImage: "shield.lefthalf.filled")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let node = entry.node {
                Text(node.name)
                    .font(.system(.title3, design: .rounded))
                    .lineLimit(1)
            }
            switch entry.status {
            case .noNode:
                Text("Connect a node with DNS64 in the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unreachable:
                Text("Node not reachable")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            case .loaded(let paused, let until, let queries, let blocked):
                stateText(paused: paused, until: until)
                    .font(.headline)
                    .foregroundStyle(paused ? .orange : .green)
                    .lineLimit(widgetFamily == .systemMedium ? 1 : 2)
                    .minimumScaleFactor(0.8)
                if let queries, let blocked {
                    // Medium shares its height with the chart: one line there.
                    let layout = widgetFamily == .systemMedium ? AnyLayout(HStackLayout(spacing: 4)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                    layout {
                        Text("\(queries) queries")
                        Text("\(blocked) blocked · 24 h")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stateText(paused: Bool, until: Date?) -> Text {
        guard paused else { return Text("Active") }
        guard let until else { return Text("Paused until resumed") }
        return Text("Paused until \(until.formatted(date: .omitted, time: .shortened))")
    }

    /// A column next to the status in medium, a row below the chart in large.
    private func buttons(paused: Bool) -> some View {
        let large = widgetFamily == .systemLarge
        let layout = large ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 6))
        return layout {
            if paused {
                Button(intent: ResumeDNS64Intent(node: entry.node)) {
                    Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .tint(.green)
            } else {
                Button(intent: PauseDNS64Intent(node: entry.node, minutes: 15)) {
                    Label("15 min", systemImage: "pause.fill").frame(maxWidth: .infinity)
                }
                Button(intent: PauseDNS64Intent(node: entry.node, minutes: 60)) {
                    Label("1 h", systemImage: "pause.fill").frame(maxWidth: .infinity)
                }
            }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .tint(.orange)
        .frame(width: large ? nil : 110)
    }
}

/// Stacked Allowed (green) / Blocked (red) bars of the last 24 h; no axes, only a "max N" label (no touch readout in widgets).
struct DNS64QueriesChart: View {
    let bars: [DNS64Entry.Bar]

    var body: some View {
        let maxValue = max(bars.map { $0.allowed + $0.blocked }.max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 2) {
            Chart(bars) { bar in
                BarMark(x: .value("Time", String(bar.index)), y: .value("Queries", bar.allowed))
                    .foregroundStyle(.green)
                BarMark(x: .value("Time", String(bar.index)), y: .value("Queries", bar.blocked))
                    .foregroundStyle(.red)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...maxValue)
            .frame(minHeight: 24, maxHeight: .infinity)
            .accessibilityLabel("Queries of the last 24 hours, \(bars.count) bars, maximum \(maxValue.formatted())")
            Text("max \(maxValue.formatted()) · 24 h")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct DNS64Widget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: AppConfig.dns64WidgetKind, intent: DNS64WidgetIntent.self, provider: DNS64Provider()) { entry in
            DNS64WidgetView(entry: entry)
        }
        .configurationDisplayName("DNS64")
        .description("Blocking status of a directly connected node; chart and pause/resume in the medium and large sizes.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    DNS64Widget()
} timeline: {
    DNS64Entry(date: .now, node: DNS64NodeEntity(id: "1", name: "Node64"),
               status: .loaded(paused: false, pausedUntil: nil, queries: 12_345, blocked: 1_234), bars: DNS64Entry.sampleBars)
    DNS64Entry(date: .now, node: DNS64NodeEntity(id: "1", name: "Node64"),
               status: .loaded(paused: true, pausedUntil: .now.addingTimeInterval(900), queries: 12_345, blocked: 1_234))
    DNS64Entry(date: .now, node: DNS64NodeEntity(id: "1", name: "Node64"), status: .unreachable)
}
