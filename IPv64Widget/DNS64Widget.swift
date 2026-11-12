import Foundation
import WidgetKit
import AppIntents
import SwiftUI
import IPv64

struct DNS64Entry: TimelineEntry {
    enum Status {
        /// The widget account has no directly connected node with DNS64.
        case noNode
        case unreachable
        /// `pausedUntil` nil while paused = until resumed.
        case loaded(paused: Bool, pausedUntil: Date?, queries: Int?, blocked: Int?)
    }

    let date: Date
    let node: DNS64NodeEntity?
    let status: Status
}

struct DNS64Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DNS64Entry {
        DNS64Entry(date: .now, node: DNS64NodeEntity(id: "preview", name: "Node64"),
                   status: .loaded(paused: false, pausedUntil: nil, queries: 12_345, blocked: 1_234))
    }

    func snapshot(for configuration: DNS64WidgetIntent, in context: Context) async -> DNS64Entry {
        context.isPreview ? placeholder(in: context) : await load(configuration)
    }

    func timeline(for configuration: DNS64WidgetIntent, in context: Context) async -> Timeline<DNS64Entry> {
        let entry = await load(configuration)
        var next = Date.now.addingTimeInterval(15 * 60)
        // A timed pause ends on the node by itself; refresh right after it.
        if case .loaded(true, let until?, _, _) = entry.status, until < next { next = until.addingTimeInterval(5) }
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func load(_ configuration: DNS64WidgetIntent) async -> DNS64Entry {
        guard let resolved = DNS64Nodes.resolve(configuration.node?.id) else {
            return DNS64Entry(date: .now, node: nil, status: .noNode)
        }
        let dns = resolved.client.dns64
        async let status = try? dns.status()
        // The counters are optional decoration; the blocking state decides reachability.
        async let summary = try? dns.summary()
        guard let blocking = await status.map(\.blocking) else {
            return DNS64Entry(date: .now, node: resolved.node, status: .unreachable)
        }
        let totals = await summary?.summary
        let paused = blocking?.paused == true
        // Go zero dates count as "no date" (like `HcFormat.real` in the app).
        let until = blocking?.untilResumed == true ? nil : blocking?.pausedUntil.flatMap { $0.timeIntervalSince1970 > 0 ? $0 : nil }
        return DNS64Entry(date: .now, node: resolved.node,
                          status: .loaded(paused: paused, pausedUntil: paused ? until : nil,
                                          queries: totals?.total, blocked: totals?.blocked))
    }
}

struct DNS64WidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: DNS64Entry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            info
            if widgetFamily == .systemMedium, case .loaded(let paused, _, _, _) = entry.status {
                buttons(paused: paused)
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let queries, let blocked {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(queries) queries")
                        Text("\(blocked) blocked · 24 h")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stateText(paused: Bool, until: Date?) -> Text {
        guard paused else { return Text("Active") }
        guard let until else { return Text("Paused until resumed") }
        return Text("Paused until \(until.formatted(date: .omitted, time: .shortened))")
    }

    private func buttons(paused: Bool) -> some View {
        VStack(spacing: 6) {
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
        .frame(width: 110)
    }
}

struct DNS64Widget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: AppConfig.dns64WidgetKind, intent: DNS64WidgetIntent.self, provider: DNS64Provider()) { entry in
            DNS64WidgetView(entry: entry)
        }
        .configurationDisplayName("DNS64")
        .description("Blocking status of a directly connected node; pause or resume in the medium size.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    DNS64Widget()
} timeline: {
    DNS64Entry(date: .now, node: DNS64NodeEntity(id: "1", name: "Node64"),
               status: .loaded(paused: false, pausedUntil: nil, queries: 12_345, blocked: 1_234))
    DNS64Entry(date: .now, node: DNS64NodeEntity(id: "1", name: "Node64"),
               status: .loaded(paused: true, pausedUntil: .now.addingTimeInterval(900), queries: 12_345, blocked: 1_234))
    DNS64Entry(date: .now, node: DNS64NodeEntity(id: "1", name: "Node64"), status: .unreachable)
}
