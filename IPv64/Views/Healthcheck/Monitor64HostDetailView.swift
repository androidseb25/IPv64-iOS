import SwiftUI
import IPv64

/// Detail of a Monitor64 host of a connected node (direct access).
struct Monitor64HostDetailView: View {
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(\.dismiss) private var dismiss

    let nodeId: String
    let uid: String
    /// Tells the list that this host changed (pause, edit, delete).
    let onChanged: () -> Void

    @State private var detail: Node64.Monitor64HostDetail?
    @State private var problems: [Node64.Monitor64Problem] = []
    @State private var problemsError: String?
    @State private var range = Node64.Monitor64SeriesRange.day
    @State private var charts: [String: [StatsLine]] = [:]
    @State private var chartsLoaded = false
    @State private var chartsOpen = true
    @State private var problemsOpen = true
    @State private var serviceChartsOpen = false
    @State private var serviceChartLines: [String: [StatsLine]] = [:]
    @State private var serviceChartsLoaded = false
    @State private var generation = 0
    @State private var busy = false
    @State private var isLoading = false
    @State private var confirmDelete = false
    @State private var showEdit = false
    @State private var error: ErrorText?

    private struct ChartKey: Equatable { let range: Node64.Monitor64SeriesRange, generation: Int }
    private struct ServiceChartKey: Equatable { let range: Node64.Monitor64SeriesRange, generation: Int, open: Bool }

    /// One chart per service and unit, built from the service's current metrics.
    private struct ServiceChart: Identifiable {
        let id: String
        let title: String
        let unit: String
        let top: Double?
        let series: [(key: String, label: String)]
    }

    private static let ranges: [(Node64.Monitor64SeriesRange, LocalizedStringKey)] = [
        (.sixHours, "6 h"), (.day, "24 h"), (.week, "7 d"), (.month, "30 d"),
    ]

    private var client: Node64? { nodes.client(for: nodeId) }
    private var host: Node64.Monitor64Host? { detail?.host }

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(confirmDelete || showEdit ? .clear : .orange)
        } else {
            content
        }
    }

    private var content: some View {
        List {
            if let detail {
                stateSection(detail)
                infoSection(detail)
                actions
                if !(detail.charts ?? []).isEmpty && (!charts.isEmpty || !chartsLoaded) { chartsSection(detail) }
                serviceChartsSection(detail)
                problemsSection
                newServicesSection(detail)
                ForEach(serviceGroups(detail), id: \.category) { group in
                    Section(group.category.prefix(1).uppercased() + group.category.dropFirst()) {
                        ForEach(group.services, id: \.key) { serviceRow($0) }
                    }
                }
                if !(detail.accesses ?? []).isEmpty {
                    Section("Accesses") { ForEach(detail.accesses ?? [], id: \.uid) { accessRow($0) } }
                }
            }
        }
        .overlay {
            if detail == nil && error == nil { ProgressView() }
        }
        .disabled(busy || isLoading)
        .navigationTitle(host?.name?.nonBlank ?? String(localized: "Monitor64 host"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .refreshable { await load() }
        .task { await load() }
        .task(id: ChartKey(range: range, generation: generation)) { await loadCharts() }
        .task(id: ServiceChartKey(range: range, generation: generation, open: serviceChartsOpen)) { await loadServiceCharts() }
        .sheet(isPresented: $showEdit) {
            Monitor64HostFormView(nodeId: nodeId, uid: uid) {
                onChanged()
                Task { await load() }
            }
        }
        .alert("Delete host?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(host?.name ?? uid)\" will be removed from Monitor64. Its history is kept.")
        }
        .errorAlert($error)
    }

    // MARK: Sections

    private func stateSection(_ d: Node64.Monitor64HostDetail) -> some View {
        let display = Monitor64Display.host(view: d.view?.rawValue, paused: host?.paused)
        return Section {
            HcDetailRow(title: host?.name?.nonBlank ?? String(localized: "(unnamed)"),
                        subtitle: [host?.address].compactMap { $0?.nonBlank }) {
                HealthcheckTag(text: LocalizedStringKey(display.label), color: display.color)
            }
        }
    }

    @ViewBuilder private func infoSection(_ d: Node64.Monitor64HostDetail) -> some View {
        let maintenance = d.maint.map { m in
            [m.reason?.nonBlank, HcFormat.time(m.end).map { String(localized: "until \($0)") }]
                .compactMap { $0 }.joined(separator: " · ").nonBlank ?? String(localized: "Running")
        }
        let rows: [String?] = [host?.kind?.rawValue, host?.group, (host?.tags ?? []).joined(separator: ", "),
                    HcFormat.time(d.checked), d.unreach, maintenance, host?.notes]
        if rows.contains(where: { $0?.nonBlank != nil }) || (host?.intervalSec ?? 0) > 0 {
            Section("Host") {
                HcInfoRow("Kind", host?.kind?.rawValue)
                HcInfoRow("Group", host?.group)
                HcInfoRow("Tags", (host?.tags ?? []).joined(separator: ", "))
                HcInfoRow("Last check", HcFormat.timeWithRelative(d.checked))
                HcInfoRow("Unreachable", d.unreach?.m64Text, color: .red)
                HcInfoRow("Maintenance", maintenance)
                HcInfoRow("Interval", host?.intervalSec.flatMap { $0 > 0 ? "\($0) s" : nil })
                HcInfoRow("Notes", host?.notes)
            }
        }
    }

    private var actions: some View {
        Section {
            let paused = host?.paused == true
            Button {
                Task { await setPaused(!paused) }
            } label: {
                Label(paused ? "Resume" : "Pause", systemImage: paused ? "play" : "pause")
            }
            Button {
                Task { await act { _ = try await $0.monitor64.hosts.discover(uid) } }
            } label: {
                Label("Discover services", systemImage: "arrow.clockwise")
            }
        }
        .tint(.primary)
    }

    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(Self.ranges, id: \.0) { Text($0.1).tag($0.0) }
        }
        .pickerStyle(.segmented)
    }

    private func chartsSection(_ d: Node64.Monitor64HostDetail) -> some View {
        HcCollapsibleSection(title: "Charts", isExpanded: $chartsOpen) {
            rangePicker
            ForEach(d.charts ?? [], id: \.id) { chart in
                if let lines = charts[chart.id?.rawValue ?? ""] {
                    Monitor64ChartView(title: (chart.id?.rawValue ?? "").uppercased(), unit: chart.unit ?? "",
                                       top: (chart.max ?? lines.flatMap(\.points).map(\.value).max() ?? 1).nonZero,
                                       lines: lines)
                }
            }
            if chartsLoaded && charts.isEmpty {
                Text("No data in this range.").font(.footnote).foregroundStyle(.secondary)
            } else if !chartsLoaded {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    /// Further charts from the numeric metrics of the services (only series that have a history in the range).
    @ViewBuilder private func serviceChartsSection(_ d: Node64.Monitor64HostDetail) -> some View {
        let list = serviceCharts(d)
        if !list.isEmpty {
            HcCollapsibleSection(title: "Service charts", isExpanded: $serviceChartsOpen) {
                // The range picker sits in Charts; without host charts it is shown here.
                if (d.charts ?? []).isEmpty || (chartsLoaded && charts.isEmpty) { rangePicker }
                if !serviceChartsLoaded {
                    ProgressView().frame(maxWidth: .infinity)
                } else if serviceChartLines.isEmpty {
                    Text("No data in this range.").font(.footnote).foregroundStyle(.secondary)
                } else {
                    ForEach(list) { chart in
                        if let lines = serviceChartLines[chart.id] {
                            Monitor64ChartView(title: chart.title, unit: chart.unit,
                                               top: (chart.top ?? lines.flatMap(\.points).map(\.value).max() ?? 1).nonZero,
                                               lines: lines)
                        }
                    }
                }
            }
        }
    }

    private var problemsSection: some View {
        HcCollapsibleSection(title: "Problems", isExpanded: $problemsOpen) {
            if let problemsError {
                Text(verbatim: problemsError).foregroundStyle(.red)
            } else if problems.isEmpty {
                Text("No open problems")
            } else {
                ForEach(problems, id: \.uid) { problem in
                    let acked = problem.ack != nil
                    let display = Monitor64Display.host(view: problem.state?.rawValue, paused: false)
                    HcDetailRow(
                        title: problem.name?.nonBlank?.m64Text ?? String(localized: "Host unreachable"),
                        subtitle: [HcFormat.time(problem.opened).map { String(localized: "Since \($0)") },
                                   acked ? String(localized: "Acknowledged") : nil].compactMap { $0 }
                            .joined(separator: " · ").nonBlank.map { [$0] } ?? []
                    ) { HealthcheckTag(text: LocalizedStringKey(display.label), color: display.color) }
                    HStack(spacing: 16) {
                        if !acked {
                            Button("Acknowledge") { Task { await problemAction(problem, .ack) } }
                        }
                        Button("Resolve") { Task { await problemAction(problem, .resolve) } }
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder private func newServicesSection(_ d: Node64.Monitor64HostDetail) -> some View {
        let keys = (d.new ?? []).compactMap(\.key)
        if !keys.isEmpty {
            Section("New services") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(keys.count) newly discovered")
                    Text(verbatim: (d.new ?? []).compactMap { $0.name?.nonBlank?.m64Text ?? $0.key }.prefix(5).joined(separator: ", ")
                         + (keys.count > 5 ? " …" : ""))
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                }
                HStack(spacing: 16) {
                    Button("Adopt all") { Task { await adopt(keys, .adopt) } }
                    Button("Ignore all") { Task { await adopt(keys, .ignore) } }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private struct ServiceGroup {
        let category: String
        let services: [Node64.Monitor64HostService]
    }

    /// By category in order of first appearance.
    private func serviceGroups(_ d: Node64.Monitor64HostDetail) -> [ServiceGroup] {
        var seen = Set<String>()
        let services = (d.services ?? []).filter { $0.key != nil && seen.insert($0.key ?? "").inserted }
        var order: [String] = []
        for s in services where !order.contains(s.category?.rawValue ?? "other") { order.append(s.category?.rawValue ?? "other") }
        return order.map { category in
            ServiceGroup(category: category, services: services.filter { ($0.category?.rawValue ?? "other") == category })
        }
    }

    /// Series already in the host charts are left out; `%` charts go up to 100, others to the metric's maximum (e.g. disk size).
    private func serviceCharts(_ d: Node64.Monitor64HostDetail) -> [ServiceChart] {
        let hostKeys = Set((d.charts ?? []).flatMap { $0.series ?? [] }.map { "\($0.svc ?? "")|\($0.metric ?? "")" })
        return serviceGroups(d).flatMap(\.services).flatMap { s -> [ServiceChart] in
            guard let key = s.key else { return [] }
            let metrics = (s.metrics ?? []).filter { m in
                guard m.value != nil, let name = m.name?.nonBlank else { return false }
                return !hostKeys.contains("\(key)|\(name)")
            }
            var units: [String] = []
            for m in metrics where !units.contains(m.unit ?? "") { units.append(m.unit ?? "") }
            let title = (s.customName?.nonBlank ?? s.name?.nonBlank ?? key).m64Text
            return units.map { unit in
                let group = metrics.filter { ($0.unit ?? "") == unit }
                return ServiceChart(id: "\(key)|\(unit)", title: units.count > 1 && !unit.isEmpty ? "\(title) (\(unit))" : title,
                                    unit: unit, top: unit == "%" ? 100 : group.compactMap(\.max).max(),
                                    series: group.map { ("\(key)|\($0.name ?? "")", $0.name ?? "") })
            }
        }
    }

    private func serviceRow(_ s: Node64.Monitor64HostService) -> some View {
        let display = Monitor64Display.service(s.state?.rawValue)
        let metrics = (s.metrics ?? []).compactMap { m -> String? in
            guard let value = m.value else { return nil }
            let number = value.formatted(.number.precision(.fractionLength(0...1)))
            return "\(m.name ?? "") \(number)\(m.unit?.nonBlank.map { " \($0)" } ?? "")".trimmingCharacters(in: .whitespaces)
        }.joined(separator: " · ")
        return HcDetailRow(
            title: (s.customName?.nonBlank ?? s.name?.nonBlank ?? s.key ?? "").m64Text,
            subtitle: [s.text?.m64Text, metrics].compactMap { $0?.nonBlank }
        ) { HealthcheckTag(text: LocalizedStringKey(display.label), color: display.color) }
    }

    private func accessRow(_ a: Node64.Monitor64AccessState) -> some View {
        let (label, color): (String, Color) = {
            if a.enabled == false { return ("Off", .gray) }
            if a.known != true { return ("Unknown", .gray) }
            return a.ok == true ? ("OK", .green) : ("Error", .red)
        }()
        return HcDetailRow(
            title: (a.name?.nonBlank ?? a.type?.rawValue ?? "").m64Text,
            subtitle: [a.type?.rawValue, a.error?.nonBlank?.m64Text].compactMap { $0 }
        ) { HealthcheckTag(text: LocalizedStringKey(label), color: color) }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Edit", systemImage: "pencil") { showEdit = true }
                .disabled(detail == nil || busy || isLoading)
        }
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if busy || isLoading {
                ProgressView()
            } else {
                Button("Delete host", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    .tint(.red)
                    .disabled(detail == nil)
            }
        }.appVerticalPreferred()
    }

    // MARK: Loading

    private func load() async {
        guard let client else {
            error = ErrorText(title: String(localized: "Node not reachable"),
                              message: String(localized: "No local access stored for this node."))
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await client.monitor64.hosts.get(uid)
            generation += 1
        } catch is CancellationError {
            return
        } catch {
            self.error = hostError(error)
            return
        }
        // A failing problem list shows its error inline.
        do {
            problems = try await client.monitor64.problems.list(status: .open, host: uid).problems ?? []
            problemsError = nil
        } catch is CancellationError {
        } catch {
            problemsError = ErrorText.node(error).message
        }
    }

    /// Host charts of the range; an error only hides the charts.
    private func loadCharts() async {
        guard let client, let detail else { return }
        chartsLoaded = false
        defer { chartsLoaded = true }
        let keys = (detail.charts ?? []).flatMap { $0.series ?? [] }.map { "\($0.svc ?? "")|\($0.metric ?? "")" }
        let points = await fetchSeries(keys, client: client)
        var lines: [String: [StatsLine]] = [:]
        for chart in detail.charts ?? [] {
            let chartLines = (chart.series ?? []).compactMap { series -> StatsLine? in
                let key = "\(series.svc ?? "")|\(series.metric ?? "")"
                guard let p = points[key] else { return nil }
                return StatsLine(name: series.label?.nonBlank ?? key, points: p)
            }
            if !chartLines.isEmpty { lines[chart.id?.rawValue ?? ""] = chartLines }
        }
        charts = lines
    }

    /// Service charts, only while their section is open.
    private func loadServiceCharts() async {
        guard serviceChartsOpen, let client, let detail else { return }
        serviceChartsLoaded = false
        defer { serviceChartsLoaded = true }
        let list = serviceCharts(detail)
        // shortcut: at most 64 series (4 calls); load per chart on demand if hosts with more metrics are common.
        let points = await fetchSeries(Array(list.flatMap { $0.series.map(\.key) }.prefix(64)), client: client)
        var lines: [String: [StatsLine]] = [:]
        for chart in list {
            let chartLines = chart.series.compactMap { s in points[s.key].map { StatsLine(name: s.label, points: $0) } }
            if !chartLines.isEmpty { lines[chart.id] = chartLines }
        }
        serviceChartLines = lines
    }

    /// Averages per `service|metric` key with at least two points, in calls of at most 16 series (server limit).
    /// A failing call only drops its series.
    private func fetchSeries(_ keys: [String], client: Node64) async -> [String: [StatsLine.Point]] {
        var unique: [String] = []
        for key in keys where !unique.contains(key) { unique.append(key) }
        var result: [String: [StatsLine.Point]] = [:]
        for start in stride(from: 0, to: unique.count, by: 16) {
            let batch = Array(unique[start..<min(start + 16, unique.count)])
            guard let series = try? await client.monitor64.series(host: uid, series: batch, range: range) else { continue }
            for entry in series.series ?? [] {
                guard let key = entry.s else { continue }
                let points = (entry.points ?? []).compactMap { p -> StatsLine.Point? in
                    guard let t = p.t, let avg = p.avg else { return nil }
                    return StatsLine.Point(time: Date(timeIntervalSince1970: TimeInterval(t)), value: avg)
                }.sorted { $0.time < $1.time }
                if points.count >= 2 { result[key] = points }
            }
        }
        return result
    }

    // MARK: Actions

    /// Runs an action with the spinner, then reloads.
    private func act(_ block: (Node64) async throws -> Void) async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        do {
            try await block(client)
            onChanged()
        } catch is CancellationError {
            return
        } catch {
            self.error = ErrorText.node(error)
            return
        }
        await load()
    }

    private func setPaused(_ paused: Bool) async {
        guard let h = host else { return }
        // PUT replaces all fields: take over the values of the loaded host.
        let input = Node64.Monitor64HostInput(
            name: h.name ?? "", address: h.address ?? "", kind: h.kind, group: h.group, tags: h.tags,
            intervalSec: h.intervalSec, notes: h.notes, paused: paused, agentAutoupdate: h.agentAutoupdate)
        await act { _ = try await $0.monitor64.hosts.update(uid, input) }
    }

    private func problemAction(_ problem: Node64.Monitor64Problem, _ action: Node64.Monitor64ProblemActionAction) async {
        await act { _ = try await $0.monitor64.problems.perform(.init(host: uid, key: problem.key, action: action)) }
    }

    private func adopt(_ keys: [String], _ state: Node64.Monitor64AdoptState) async {
        await act { _ = try await $0.monitor64.hosts.adoptServices(host: uid, keys: keys, state: state) }
    }

    private func delete() async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        do {
            try await client.monitor64.hosts.delete(uid)
            onChanged()
            dismiss()
        } catch is CancellationError {
        } catch {
            self.error = hostError(error)
        }
    }
}

/// 404: host deleted or Monitor64 off; else the general node error text.
func hostError(_ error: any Error) -> ErrorText {
    isNodeNotFound(error)
        ? ErrorText(title: String(localized: "Host not found"),
                    message: String(localized: "Host not found or Monitor64 is off on this node."))
        : .node(error)
}

private extension Double {
    var nonZero: Double { self > 0 ? self : 1 }
}
