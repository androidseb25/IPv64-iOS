import SwiftUI
import Charts
import IPv64

/// Read-only module screen over the stored direct connection (DNS64 and Honeypot only).
struct NodeModuleView: View {
    @Environment(ConnectedNodes.self) private var nodes
    let nodeId: String
    let module: String

    static func hasScreen(_ name: String) -> Bool { ["dns64", "honeypot"].contains(name.lowercased()) }

    private var isDns: Bool { module.lowercased() == "dns64" }

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(.orange)
        } else {
            content
        }
    }

    @ViewBuilder private var content: some View {
        Group {
            if let client = nodes.client(for: nodeId) {
                if isDns { Dns64ModuleList(client: client) } else { HoneypotModuleList(client: client) }
            } else {
                ContentUnavailableView("No direct connection to this node.", systemImage: "network.slash")
            }
        }
        .navigationTitle(isDns ? String(localized: "DNS64") : String(localized: "Honeypot"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Runs one request of a module screen; a failure becomes a value so the other requests go on.
private nonisolated func attempt<T: Sendable>(_ operation: @Sendable () async throws -> T) async -> Result<T, any Error> {
    do { return .success(try await operation()) } catch { return .failure(error) }
}

private func moduleErrorText(_ error: any Error) -> String {
    if (error as? Node64Error)?.statusCode == 404 { return String(localized: "Not available on this node.") }
    return ErrorText.node(error).titledText
}

// MARK: - DNS64

private struct Dns64ModuleList: View {
    let client: Node64

    @State private var status: Result<Node64.DNS64Status, any Error>?
    @State private var summary: Result<Node64.DNS64Summary, any Error>?
    @State private var blocked: Result<[Node64.DNS64TopItem], any Error>?
    @State private var allowed: Result<[Node64.DNS64TopItem], any Error>?
    @State private var clients: Result<[Node64.DNS64TopItem], any Error>?
    @State private var loaded = false

    var body: some View {
        List {
            if loaded {
                if let status { statusSection(status) }
                if let summary { summarySection(summary) }
                if let blocked { topSection("Top blocked domains", blocked) }
                if let allowed { topSection("Top queried domains", allowed) }
                if let clients { topSection("Top clients", clients) }
            }
        }
        .overlay { if !loaded { ProgressView() } }
        .refreshable { await load() }
        .task { await load() }
    }

    @ViewBuilder private func statusSection(_ result: Result<Node64.DNS64Status, any Error>) -> some View {
        switch result {
        case .failure(let error):
            ModuleErrorSection(title: "Status", error: error)
        case .success(let s):
            Section("Status") {
                ModuleInfoRow("Version", s.version)
                ModuleInfoRow("Listen", s.listen, mono: true)
                ModuleInfoRow("Filtering", s.blocking?.paused == true ? String(localized: "Paused") : String(localized: "Active"))
                ModuleInfoRow("Running since", HcFormat.time(s.startedAt))
            }
        }
    }

    @ViewBuilder private func summarySection(_ result: Result<Node64.DNS64Summary, any Error>) -> some View {
        switch result {
        case .failure(let error):
            ModuleErrorSection(title: "Last 24 hours", error: error)
        case .success(let value):
            let s = value.summary
            let total = s?.total ?? 0
            Section("Last 24 hours") {
                ModuleBigNumber(value: total.formatted(), label: "Queries")
                LabeledContent("Blocked", value: (s?.blocked ?? 0).formatted())
                LabeledContent("Blocked %", value: NodesLogic.blockedPercent(total: total, blocked: s?.blocked ?? 0))
                LabeledContent("Clients", value: (s?.clients ?? 0).formatted())
            }
        }
    }

    @ViewBuilder private func topSection(_ title: LocalizedStringKey, _ result: Result<[Node64.DNS64TopItem], any Error>) -> some View {
        switch result {
        case .failure(let error):
            ModuleErrorSection(title: title, error: error)
        case .success(let items) where !items.isEmpty:
            let maxValue = items.compactMap(\.count).max() ?? 0
            Section(title) {
                ForEach(items.indices, id: \.self) { i in
                    let item = items[i]
                    ModuleRankRow(label: item.name?.nonBlank ?? item.hostname?.nonBlank ?? "–",
                                  subtitle: item.name?.nonBlank != nil ? item.hostname?.nonBlank : nil,
                                  value: item.count ?? 0, detail: (item.count ?? 0).formatted(), maxValue: maxValue, mono: true)
                }
            }
        case .success:
            EmptyView()
        }
    }

    private func load() async {
        let dns = client.dns64
        async let status = attempt { try await dns.status() }
        async let summary = attempt { try await dns.summary(range: .last24Hours) }
        async let blocked = attempt { try await dns.top(kind: .blocked, range: .last24Hours, limit: 10) }
        async let allowed = attempt { try await dns.top(kind: .allowed, range: .last24Hours, limit: 10) }
        async let clients = attempt { try await dns.top(kind: .clients, range: .last24Hours, limit: 10) }
        let results = await (status, summary, blocked, allowed, clients)
        if Task.isCancelled { return }
        (self.status, self.summary, self.blocked, self.allowed, self.clients) = results
        loaded = true
    }
}

// MARK: - Honeypot

private struct HoneypotModuleList: View {
    let client: Node64

    @State private var status: Result<Node64.Honeypot64Status, any Error>?
    @State private var stats: Result<Node64.Honeypot64Stats, any Error>?
    @State private var events: Result<[Node64.Honeypot64Event], any Error>?
    @State private var loaded = false
    @State private var range = HoneypotRange.day
    @State private var rangeLoading = false

    /// Periods of the honeypot statistics (`since`); the timeline is hourly up to 48 h, daily above.
    enum HoneypotRange: String, CaseIterable, Identifiable {
        case day = "24h", week = "7d", month = "30d"
        var id: Self { self }
        var label: LocalizedStringKey {
            switch self {
            case .day: "24 h"
            case .week: "7 d"
            case .month: "30 d"
            }
        }
        var title: LocalizedStringKey {
            switch self {
            case .day: "Last 24 hours"
            case .week: "Last 7 days"
            case .month: "Last 30 days"
            }
        }
        var unit: Calendar.Component { self == .day ? .hour : .day }
    }

    private struct Bar: Identifiable {
        let time: Date
        let events: Int
        var id: Date { time }
    }

    var body: some View {
        List {
            if loaded {
                if let status { statusSection(status) }
                Section {
                    Picker("Range", selection: $range) {
                        ForEach(HoneypotRange.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(rangeLoading)
                }
                if let stats { statsSections(stats) }
                if let events { eventsSection(events) }
            }
        }
        .overlay { if !loaded { ProgressView() } }
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: range) { Task { await loadStats() } }
    }

    @ViewBuilder private func statusSection(_ result: Result<Node64.Honeypot64Status, any Error>) -> some View {
        switch result {
        case .failure(let error):
            ModuleErrorSection(title: "Status", error: error)
        case .success(let s):
            Section("Status") {
                LabeledContent("State") {
                    Text(s.running == true ? "Running" : "Not running").foregroundStyle(s.running == true ? .green : .orange)
                }
                ModuleInfoRow("Version", s.version)
                ModuleInfoRow("Profile", s.profile)
                ModuleInfoRow("Services", s.services.map { $0.count.formatted() })
                ModuleInfoRow("Connections", s.counters?.connections?.formatted())
                ModuleInfoRow("Logins", s.counters?.logins?.formatted())
            }
        }
    }

    @ViewBuilder private func statsSections(_ result: Result<Node64.Honeypot64Stats, any Error>) -> some View {
        switch result {
        case .failure(let error):
            ModuleErrorSection(title: range.title, error: error)
        case .success(let s):
            Section(range.title) {
                ModuleBigNumber(value: (s.events ?? 0).formatted(), label: "Events")
                LabeledContent("Sources", value: (s.sources ?? 0).formatted())
                LabeledContent("Logins", value: (s.logins ?? 0).formatted())
            }
            let bars = (s.timeline ?? []).compactMap { point in point.time.map { Bar(time: $0, events: point.events ?? 0) } }
            if bars.contains(where: { $0.events > 0 }) {
                Section("Attacks") {
                    Chart(bars) { bar in
                        BarMark(x: .value("Time", bar.time, unit: range.unit), y: .value("Events", bar.events))
                            .foregroundStyle(Color.orange)
                    }
                    .frame(height: 140)
                    .accessibilityLabel("Bar chart with \(bars.count) values, maximum \(bars.map(\.events).max() ?? 0)")
                }
            }
            rankSection("Top attackers", (s.topSources ?? []).map {
                ($0.key ?? "–", $0.count ?? 0,
                 [($0.count ?? 0).formatted(), NodesLogic.countryFlag($0.country)].compactMap { $0 }.joined(separator: " · "))
            })
            rankSection("Top ports", counts(s.byPort))
            rankSection("Top countries", (s.byCountry ?? []).map {
                ([NodesLogic.countryFlag($0.key), $0.key].compactMap { $0 }.joined(separator: " ").nonBlank ?? "–", $0.count ?? 0,
                 String(localized: "\(($0.count ?? 0).formatted()) · \($0.sources ?? 0) sources"))
            })
            rankSection("Services", counts(s.byService))
            rankSection("Attack kinds", counts(s.byKind))
            rankSection("Usernames", counts(s.topUsers), mono: true)
            rankSection("Passwords", counts(s.topPasswords), mono: true)
            rankSection("Paths", counts(s.topPaths), mono: true)
            rankSection("User agents", counts(s.topUserAgents))
        }
    }

    private func counts(_ list: [Node64.Honeypot64Count]?) -> [(String, Int, String)] {
        (list ?? []).map { ($0.key ?? "–", $0.count ?? 0, ($0.count ?? 0).formatted()) }
    }

    @ViewBuilder private func rankSection(_ title: LocalizedStringKey, _ rows: [(String, Int, String)], mono: Bool = false) -> some View {
        if !rows.isEmpty {
            let top = Array(rows.prefix(10))
            let maxValue = top.map(\.1).max() ?? 0
            Section(title) {
                ForEach(top.indices, id: \.self) { i in
                    ModuleRankRow(label: top[i].0, value: top[i].1, detail: top[i].2, maxValue: maxValue, mono: mono)
                }
            }
        }
    }

    @ViewBuilder private func eventsSection(_ result: Result<[Node64.Honeypot64Event], any Error>) -> some View {
        switch result {
        case .failure(let error):
            ModuleErrorSection(title: "Recent events", error: error)
        case .success(let list) where !list.isEmpty:
            Section("Recent events") {
                ForEach(list.indices, id: \.self) { i in
                    let e = list[i]
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.src?.nonBlank ?? "–").font(.body.monospaced())
                        Text([HcFormat.real(e.time).map { $0.formatted(.relative(presentation: .named)) },
                              e.service?.nonBlank ?? e.port.map { "port \($0)" }, NodesLogic.countryFlag(e.country)]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        case .success:
            EmptyView()
        }
    }

    private func load() async {
        let honeypot = client.honeypot
        async let status = attempt { try await honeypot.status() }
        let since = range.rawValue
        async let stats = attempt { try await honeypot.stats(since: since, top: 10) }
        async let events = attempt { try await honeypot.events(limit: 20) }
        let results = await (status, stats, events)
        if Task.isCancelled { return }
        (self.status, self.stats, self.events) = results
        loaded = true
    }

    /// A new period reloads only the statistics.
    private func loadStats() async {
        let honeypot = client.honeypot
        let since = range.rawValue
        rangeLoading = true
        defer { rangeLoading = false }
        let result = await attempt { try await honeypot.stats(since: since, top: 10) }
        if Task.isCancelled || since != range.rawValue { return }
        stats = result
    }
}

// MARK: - Rows

/// Prominent value with a caption (like the healthcheck statistics).
private struct ModuleBigNumber: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 40, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.5)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// `LabeledContent` that disappears for blank values.
private struct ModuleInfoRow: View {
    let label: LocalizedStringKey
    let value: String?
    var mono = false

    init(_ label: LocalizedStringKey, _ value: String?, mono: Bool = false) {
        self.label = label
        self.value = value?.nonBlank
        self.mono = mono
    }

    var body: some View {
        if let value {
            LabeledContent(label) { Text(value).font(mono ? .body.monospaced() : .body).textSelection(.enabled) }
        }
    }
}

private struct ModuleErrorSection: View {
    let title: LocalizedStringKey
    let error: any Error

    var body: some View {
        Section(title) { Text(moduleErrorText(error)).foregroundStyle(.red) }
    }
}

/// Ranking row: label, count, bar relative to the largest value.
private struct ModuleRankRow: View {
    let label: String
    var subtitle: String?
    let value: Int
    let detail: String
    let maxValue: Int
    var mono = false

    private var fraction: Double {
        value == 0 || maxValue == 0 ? 0 : min(max(Double(value) / Double(maxValue), 0.02), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(mono ? .body.monospaced() : .body).lineLimit(2)
                    if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
                }
                Spacer(minLength: 8)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            ProgressView(value: fraction).tint(.orange)
        }
        .accessibilityElement(children: .combine)
    }
}
