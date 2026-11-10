import SwiftUI
import IPv64

/// Node check detail (spec 02 B6): direct node, local API.
struct NodeCheckDetailView: View {
    let nodeId: String
    let token: String

    @Environment(ConnectedNodes.self) private var nodes
    @Environment(Router.self) private var router

    @State private var chk: Node64.Check?
    @State private var nodeError: String?
    @State private var events: [Node64.CheckEvent] = []
    @State private var eventsError: String?
    @State private var incidents: [Node64.CheckIncident] = []
    @State private var incidentsError: String?
    @State private var measurements: [Node64.CheckMeasurement] = []
    @State private var statsRange: Node64.CheckStatsRange = .last24Hours
    @State private var statsCache: [Node64.CheckStatsRange: Node64.CheckStats] = [:]
    @State private var statsError: String?
    @State private var statsLoading = false
    @State private var generation = 0
    @State private var loaded = false
    @State private var busyText: LocalizedStringKey?
    @State private var error: ErrorText?
    @State private var confirm: ConfirmRequest?

    private struct StatsKey: Equatable { let range: Node64.CheckStatsRange, generation: Int }

    private var client: Node64? { nodes.client(for: nodeId) }

    var body: some View {
        Group {
            if !loaded { LoadingView() } else { content }
        }
        .navigationTitle(chk?.name?.nonBlank ?? String(localized: "Healthcheck"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") { router.push(.nodeCheckEdit(nodeId: nodeId, token: token)) }
                    .disabled(!editable)
            }
            AppMoreMenu {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
                Button("Delete", systemImage: "trash", role: .destructive) { askDelete() }.disabled(chk == nil)
            }
        }
        .task { await load() }
        .task(id: StatsKey(range: statsRange, generation: generation)) { await loadStats() }
        .loadingOverlay(busyText != nil, text: busyText ?? "Loading...")
        .errorAlert($error)
        .confirmDialog($confirm)
    }

    /// Edit needs a known check type.
    private var editable: Bool {
        guard let type = chk?.type else { return false }
        return nodeCheckTypes.contains(type)
    }

    // MARK: Content

    private var content: some View {
        List {
            if let nodeError {
                Section {
                    Text(verbatim: nodeError).foregroundStyle(Color.ipv64Red)
                } footer: { Text("Check the connection under More → Nodes.") }
            }
            if let chk {
                let paused = chk.paused == true
                Section {
                    HStack {
                        Text(verbatim: header(chk))
                        Spacer(minLength: 8)
                        StatusChip(state: Hc2StateUi.from(chk.state?.state?.rawValue, paused: chk.paused))
                    }
                    ActionTileRow {
                        ActionTile(paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill") {
                            Task { await togglePause(paused: paused) }
                        }
                        ActionTile("Run now", systemImage: "arrow.clockwise") { Task { await run() } }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                Section("Status") { statusRows(chk) }
                if !measurements.isEmpty {
                    Section("Recent checks") {
                        StatusPillsBar(states: measurements.map {
                            $0.status == .up ? .up : $0.status == .down ? .down : .unknown
                        }, noun: "checks")
                    }
                }
                Section("Statistics") { statsRows }
                Section("Incidents") { incidentRows }
                Section("Events") { eventRows }
            }
        }
        .refreshable { await load() }
    }

    private func header(_ chk: Node64.Check) -> String {
        let text = [chk.type?.rawValue.uppercased(), chk.target?.nonBlank].compactMap { $0?.nonBlank }.joined(separator: " · ")
        return text.isEmpty ? "–" : text
    }

    @ViewBuilder
    private func statusRows(_ chk: Node64.Check) -> some View {
        let s = chk.state
        let time: (String?) -> String? = { Formatters.parseISO($0).map(Formatters.germanTime) }
        let timeAgo: (String?) -> String? = { raw in
            Formatters.parseISO(raw).map { "\(Formatters.germanTime($0)) (\(Formatters.relative($0)))" }
        }
        HcInfoRow("Since", time(s?.since))
        HcInfoRow("Last check", timeAgo(s?.lastCheckAt))
        HcInfoRow("Last status", s?.lastStatus)
        HcInfoRow("Latency", s?.lastLatencyMS.map(Formatters.latency))
        HcInfoRow("Reason", s?.lastReason)
        HcInfoRow("Message", s?.lastMessage)
        HcInfoRow("Down since", time(s?.downSince), color: .ipv64Red)
        HcInfoRow("Interval", chk.intervalSeconds.map { "\($0) s" })
        HcInfoRow("Description", chk.description)
    }

    @ViewBuilder
    private var statsRows: some View {
        Picker("Range", selection: $statsRange) {
            Text("1 h").tag(Node64.CheckStatsRange.lastHour)
            Text("24 h").tag(Node64.CheckStatsRange.last24Hours)
            Text("7 d").tag(Node64.CheckStatsRange.last7Days)
            Text("30 d").tag(Node64.CheckStatsRange.last30Days)
            Text("1 y").tag(Node64.CheckStatsRange.lastYear)
        }
        .pickerStyle(.segmented)
        if let stats = statsCache[statsRange] {
            LabeledContent("Uptime", value: Formatters.percent(stats.upPercent))
            LabeledContent("Measurements", value: stats.count.map(Formatters.count) ?? "–")
            LabeledContent("Response time",
                           value: "min \(Formatters.latency(stats.minMS)) · avg \(Formatters.latency(stats.avgMS)) · max \(Formatters.latency(stats.maxMS))")
            let lines = statsLines(stats)
            if lines.flatMap(\.points).count >= 2 {
                LatencyChart(lines: lines, dayBucket: (stats.bucketSeconds ?? 0) >= 86_400)
            }
        } else if statsLoading {
            Text("Loading...").foregroundStyle(.secondary)
        } else if let statsError {
            Text(verbatim: statsError).foregroundStyle(Color.ipv64Red)
        } else {
            Text("No data").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var incidentRows: some View {
        if let incidentsError {
            Text(verbatim: incidentsError).foregroundStyle(Color.ipv64Red)
        } else if incidents.isEmpty {
            Text("No incidents").foregroundStyle(.secondary)
        } else {
            ForEach(incidents) { NodeCheckIncidentRow(incident: $0) }
        }
    }

    @ViewBuilder
    private var eventRows: some View {
        if let eventsError {
            Text(verbatim: eventsError).foregroundStyle(Color.ipv64Red)
        } else if events.isEmpty {
            Text("No events").foregroundStyle(.secondary)
        } else {
            ForEach(events) { NodeCheckEventRow(event: $0) }
        }
    }

    // MARK: Loading

    private func load() async {
        guard let client else {
            nodeError = String(localized: "No local access stored for this node.")
            loaded = true
            return
        }
        do {
            let check = try await client.hc.checks.get(token)
            chk = check
            nodeError = nil
        } catch is CancellationError {
            return
        } catch {
            chk = nil
            nodeError = ErrorText.node(error).titledText
            loaded = true
            return
        }
        do {
            events = try await client.hc.checks.events(token, limit: 50)
            eventsError = nil
        } catch is CancellationError {
        } catch { eventsError = ErrorText.node(error).titledText }
        do {
            incidents = try await client.hc.checks.incidents(token, limit: 20)
            incidentsError = nil
        } catch is CancellationError {
        } catch { incidentsError = ErrorText.node(error).titledText }
        measurements = (try? await client.hc.checks.measurements(token, limit: 100)) ?? measurements
        statsCache = [:]
        generation += 1
        loaded = true
    }

    private func loadStats() async {
        guard let client, chk != nil, statsCache[statsRange] == nil else { return }
        let range = statsRange
        statsLoading = true
        statsError = nil
        defer { statsLoading = false }
        do {
            statsCache[range] = try await client.hc.checks.stats(token, range: range)
        } catch is CancellationError {
        } catch {
            statsError = ErrorText.node(error).message
        }
    }

    // MARK: Actions

    private func togglePause(paused: Bool) async {
        guard let client else { return }
        busyText = paused ? "Resuming..." : "Pausing..."
        do {
            if paused { _ = try await client.hc.checks.resume(token) } else { _ = try await client.hc.checks.pause(token) }
            busyText = nil
            router.reload()
            await load()
        } catch is CancellationError {
            busyText = nil
        } catch {
            busyText = nil
            self.error = ErrorText.node(error)
        }
    }

    private func run() async {
        guard let client else { return }
        busyText = "Running..."
        do {
            try await client.hc.checks.run(token)
            busyText = nil
            router.reload()
            await load()
        } catch is CancellationError {
            busyText = nil
        } catch {
            busyText = nil
            self.error = ErrorText.node(error)
        }
    }

    private func askDelete() {
        confirm = ConfirmRequest(
            title: String(localized: "Delete healthcheck?"),
            message: String(localized: "\"\(chk?.name ?? "")\" will be removed from the node."),
            confirmLabel: String(localized: "Delete"), destructive: true
        ) { Task { await delete() } }
    }

    private func delete() async {
        guard let client else { return }
        busyText = "Deleting..."
        defer { busyText = nil }
        do {
            try await client.hc.checks.delete(token)
            router.reload()
            router.pop()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText.node(error)
        }
    }
}
