import SwiftUI
import Charts
import IPv64

/// Proxy64 "Requests and traffic": stacked hourly requests plus a download/upload chart, per connected proxy node.
struct ProxyTrafficSection: View {
    /// Bumped by the Proxy64 pull-to-refresh to load the chart again.
    var refresh = 0
    @Environment(ConnectedNodes.self) private var nodes
    @State private var expanded = true
    @State private var picked: String?
    @State private var range = Period.day
    @State private var points: [ProxyStats.Point]?
    @State private var error: ErrorText?
    @State private var loading = false
    @State private var loadToken = UUID()
    /// Last key loaded: a List cancels and restarts the row's task when it scrolls back in; that must not reload.
    @State private var loadedKey: LoadKey?
    /// One selected hour for both charts (touching either highlights the same hour in both).
    @State private var rawSelection: Date?

    private enum Period: CaseIterable, Identifiable {
        case day, week
        var id: Self { self }
        var hours: Int { self == .day ? 24 : 168 }
        var label: LocalizedStringKey { self == .day ? "24 h" : "7 d" }
    }

    private struct LoadKey: Equatable { var id: String?; var range: Period; var refresh: Int }

    private var currentId: String? { picked.flatMap { nodes.proxyIds.contains($0) ? $0 : nil } ?? nodes.proxyIds.first }

    private static let requestSeries: [(name: String, color: Color)] = [
        (String(localized: "Requests answered"), .blue), (String(localized: "4xx from target"), .gray),
        (String(localized: "Errors (5xx)"), .yellow), (String(localized: "Rejected"), .red),
        (String(localized: "To honeypot"), .purple)]
    private static let download = String(localized: "Download")
    private static let upload = String(localized: "Upload")

    var body: some View {
        if let id = currentId {
            HcCollapsibleSection(title: "Requests and traffic", isExpanded: $expanded) {
                if nodes.proxyIds.count > 1 {
                    Picker("Node", selection: Binding(get: { id }, set: { picked = $0 })) {
                        ForEach(nodes.proxyIds, id: \.self) { Text(verbatim: nodes.name(of: $0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Picker("Period", selection: $range) {
                    ForEach(Period.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                // On a row, not the Section: in a List a Section's modifiers apply to every row.
                .task(id: LoadKey(id: id, range: range, refresh: refresh)) {
                    let key = LoadKey(id: id, range: range, refresh: refresh)
                    if key != loadedKey || points == nil && error == nil { await load(key) }
                }
                content
            }
        }
    }

    @ViewBuilder private var content: some View {
        if let error {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: error.title)
                Text(verbatim: error.message).font(.subheadline).foregroundStyle(.secondary)
            }
        } else if let points {
            if points.allSatisfy({ $0.requests == 0 && $0.blocked == 0 && $0.bytes == 0 && $0.up == 0 }) {
                Text("No traffic in this period.").foregroundStyle(.secondary)
            } else {
                Group {
                    requestsChart(points)
                    trafficChart(points)
                }
                // Keep the old data visible (dimmed) while the next range loads.
                .opacity(loading ? 0.4 : 1)
                .animation(.easeInOut, value: loading)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private func selected(_ points: [ProxyStats.Point]) -> ProxyStats.Point? {
        guard let raw = rawSelection else { return nil }
        // The bar of an hour spans its whole hour: pick the hour that contains the touch (points are ascending).
        return points.last { $0.time <= raw } ?? points.first
    }

    private func when(_ p: ProxyStats.Point) -> String { p.time.formatted(date: .abbreviated, time: .shortened) }

    private func requestsChart(_ points: [ProxyStats.Point]) -> some View {
        let total = points.reduce(0) { $0 + $1.requests }
        let sel = selected(points)
        let header = sel.map { p in
            Text("\(when(p))  Answered: \(Int(p.ok))  4xx: \(Int(p.c4))  5xx: \(Int(p.err))  Rejected: \(Int(p.blocked))  Honeypot: \(Int(p.decoy))  Total: \(Int(p.requests))")
        } ?? Text("Touch the chart for values")
        return VStack(alignment: .leading, spacing: 8) {
            header.font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(sel == nil)
            requestsBars(points, sel: sel, total: total)
        }
    }

    private func requestsBars(_ points: [ProxyStats.Point], sel: ProxyStats.Point?, total: Double) -> some View {
        Chart {
            ForEach(points) { p in
                ForEach(Array(zip(Self.requestSeries, [p.ok, p.c4, p.err, p.blocked, p.decoy])), id: \.0.name) { s, v in
                    BarMark(x: .value("Time", p.time, unit: .hour), y: .value("Requests", v))
                        .foregroundStyle(by: .value("Series", s.name))
                        .opacity(sel == nil || sel?.id == p.id ? 1 : 0.35)
                }
            }
        }
        .chartForegroundStyleScale(domain: Self.requestSeries.map(\.name), range: Self.requestSeries.map(\.color))
        .chartXSelection(value: $rawSelection)
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXAxis { xAxis(points) }
        .frame(height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Requests")
        .accessibilityValue(Text("\(Int(total)) requests, \(Int(points.reduce(0) { $0 + $1.blocked })) rejected"))
    }

    private func trafficChart(_ points: [ProxyStats.Point]) -> some View {
        let down = points.reduce(0) { $0 + $1.bytes }, up = points.reduce(0) { $0 + $1.up }
        let sel = selected(points)
        let header = sel.map { p in
            Text("\(when(p))  Download: \(Self.bytes(p.bytes))  Upload: \(Self.bytes(p.up))")
        } ?? Text("Touch the chart for values")
        return VStack(alignment: .leading, spacing: 8) {
            header.font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(sel == nil)
            trafficLines(points, sel: sel, down: down, up: up)
        }
    }

    private func trafficLines(_ points: [ProxyStats.Point], sel: ProxyStats.Point?, down: Double, up: Double) -> some View {
        Chart {
            if let sel { RuleMark(x: .value("Time", sel.time, unit: .hour)).foregroundStyle(.secondary.opacity(0.5)) }
            ForEach(points) { p in
                LineMark(x: .value("Time", p.time, unit: .hour), y: .value("Bytes", p.bytes), series: .value("Series", Self.download))
                    .foregroundStyle(by: .value("Series", Self.download))
            }
            ForEach(points) { p in
                LineMark(x: .value("Time", p.time, unit: .hour), y: .value("Bytes", p.up), series: .value("Series", Self.upload))
                    .foregroundStyle(by: .value("Series", Self.upload))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
            }
        }
        .chartForegroundStyleScale([Self.download: Color.cyan, Self.upload: Color.green])
        .chartXSelection(value: $rawSelection)
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXAxis { xAxis(points) }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel { if let b = value.as(Double.self) { Text(verbatim: Self.bytes(b)) } }
            }
        }
        .frame(height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Traffic")
        .accessibilityValue(Text("Download \(Self.bytes(down)), upload \(Self.bytes(up))"))
    }

    /// Format from the shown points, not `range`: the old data stays visible while the new range loads.
    private func xAxis(_ points: [ProxyStats.Point]) -> some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
            AxisGridLine()
            AxisValueLabel(format: points.count <= 24 ? .dateTime.hour() : .dateTime.weekday(.abbreviated).day())
        }
    }

    private static func bytes(_ value: Double) -> String { ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary) }

    private func load(_ key: LoadKey) async {
        let token = UUID()
        loadToken = token
        loading = true
        defer { if loadToken == token { loading = false } }
        guard let id = key.id, let proxy = nodes.client(for: id)?.proxy64 else {
            points = nil; error = ProxyLogic.noNodeError; loadedKey = key; return
        }
        do {
            let json = try await proxy.stats(hours: key.range.hours)
            var rows: [JSONValue] = []
            if case .array(let a)? = json["timeline"] { rows = a }
            guard !Task.isCancelled else { return }
            rawSelection = nil
            loadedKey = key
            withAnimation(.easeInOut) {
                error = nil
                points = ProxyStats.series(rows.compactMap(Self.row), hours: key.range.hours)
            }
        } catch {
            // A cancelled request throws URLError(.cancelled), not CancellationError.
            if !Task.isCancelled { rawSelection = nil; loadedKey = key; points = nil; self.error = .node(error) }
        }
    }

    private static func row(_ json: JSONValue) -> ProxyStats.Row? {
        guard let hour = json["hour"]?.stringValue.flatMap({ try? Date($0, strategy: .iso8601) }) else { return nil }
        func n(_ key: String) -> Double { json[key]?.doubleValue ?? 0 }
        return ProxyStats.Row(hour: hour, requests: n("requests"), c4: n("4xx"), c5: n("5xx"), bytes: n("bytes"),
                              bytesIn: n("bytes_in"), blocked: n("blocked"), decoy: n("decoy"), connBlocked: n("conn_blocked"))
    }
}
