import SwiftUI
import IPv64

/// Healthcheck detail (spec 02 B2): status, actions, statistics, incidents and events of an account check.
struct HealthcheckDetailView: View {
    let token: String

    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL

    @State private var detail: HC2CheckDetail?
    @State private var pausedOverride: Bool?
    @State private var stateOverride: HC2Check.State?
    @State private var events: [HC2Event] = []
    @State private var nextBefore: Int?
    @State private var measurements: [HC2Measurement] = []
    @State private var channels: [HC2Channel] = []
    @State private var generation = 0
    @State private var busy = false
    @State private var loadingMore = false
    @State private var failure: ErrorText?
    @State private var error: ErrorText?
    @State private var message: String?
    @State private var waiting: String?
    @State private var runRequest: UUID?
    @State private var confirm: ConfirmRequest?
    // Statistics / incidents (lazy, per range)
    @State private var statsExpanded = false
    @State private var statsRange: HC2StatsRange = .last24Hours
    @State private var statsCache: [HC2StatsRange: HC2Stats] = [:]
    @State private var statsLoading = false
    @State private var statsError: String?
    @State private var incidentsExpanded = false
    @State private var incidents: [HC2Incident]?
    @State private var incidentsLoading = false
    @State private var incidentsError: String?

    private struct StatsKey: Equatable { let expanded: Bool, range: HC2StatsRange, generation: Int, loaded: Bool }
    private struct IncidentsKey: Equatable { let expanded: Bool, generation: Int, loaded: Bool }

    private var paused: Bool { pausedOverride ?? detail?.paused ?? false }
    private var state: HC2Check.State? { stateOverride ?? detail?.state }

    var body: some View {
        Group {
            if let detail {
                content(detail)
            } else if let failure {
                ErrorStateView(title: failure.title, message: failure.message) {
                    self.failure = nil
                    Task { await load() }
                }
            } else {
                LoadingView()
            }
        }
        .navigationTitle(detail?.name?.nonBlank ?? String(localized: "Healthcheck"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") { router.push(.healthcheckForm(token: token)) }
                    .disabled(detail == nil)
            }
            AppMoreMenu {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
                Button("Delete", systemImage: "trash", role: .destructive) { askDelete() }
                    .disabled(detail == nil)
            }
        }
        .task { await load() }
        .task(id: StatsKey(expanded: statsExpanded, range: statsRange, generation: generation, loaded: detail != nil)) {
            await loadStats()
        }
        .task(id: IncidentsKey(expanded: incidentsExpanded, generation: generation, loaded: detail != nil)) {
            await loadIncidents()
        }
        .task(id: runRequest) { if runRequest != nil { await runNow() } }
        .loadingOverlay(busy)
        .errorAlert($error)
        .confirmDialog($confirm)
        .appBottomBar {
            VStack(spacing: 0) {
                if let waiting {
                    HStack(spacing: 12) { ProgressView(); Text(verbatim: waiting) }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .appGlass(RoundedRectangle(cornerRadius: 12, style: .continuous)).padding(16)
                }
                SnackbarText(message: $message)
            }
        }
    }

    // MARK: Content

    private func content(_ detail: HC2CheckDetail) -> some View {
        let uiState = Hc2StateUi.from(state?.state?.rawValue, paused: paused)
        return List {
            Section {
                HStack {
                    Text(verbatim: [detail.type.label, detail.target?.nonBlank].compactMap { $0 }.joined(separator: " · "))
                    Spacer(minLength: 8)
                    StatusChip(state: uiState)
                }
                tiles(detail)
            }
            Section("Status") { HealthcheckStatusRows(detail: detail, state: state) }
            if !measurements.isEmpty {
                Section("Recent checks") { StatusPillsBar(states: measurements.map(measurementState), noun: "checks") }
            } else if !events.isEmpty {
                Section("Recent events") {
                    StatusPillsBar(states: events.map { healthcheckEventState(kind: $0.kind?.rawValue, to: $0.toState) },
                                   noun: "events")
                }
            }
            if let sources = detail.sources, !sources.isEmpty {
                Section("Measuring points") { HealthcheckSourceRows(sources: sources) }
            }
            if detail.type == .push, let push = detail.push {
                Section("Push endpoints") { HealthcheckPushRows(push: push) }
            }
            Section("Configuration") { HealthcheckConfigRows(detail: detail, channels: channels) }
            Section {
                DisclosureGroup("Statistics", isExpanded: $statsExpanded) { statsContent }
                DisclosureGroup("Incidents", isExpanded: $incidentsExpanded) { incidentsContent }
            }
            eventsSection
        }
        .refreshable { await load() }
    }

    private func tiles(_ detail: HC2CheckDetail) -> some View {
        ActionTileRow {
            ActionTile(paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill") {
                Task { await togglePause() }
            }
            ActionTile("Run now", systemImage: "arrow.clockwise") { runRequest = UUID() }
                .disabled(waiting != nil)
            if let url = browserURL(detail) {
                ActionTile("Open in browser", systemImage: "safari") { openURL(url) }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private func browserURL(_ detail: HC2CheckDetail) -> URL? {
        guard let type = detail.type, [.http, .keyword, .json].contains(type),
              let target = detail.target, target.lowercased().hasPrefix("http") else { return nil }
        return URL(string: target)
    }

    private func measurementState(_ m: HC2Measurement) -> Hc2StateUi {
        switch m.status?.rawValue.lowercased() {
        case "up": .up
        case "down": .down
        default: .unknown
        }
    }

    @ViewBuilder
    private var statsContent: some View {
        Picker("Range", selection: $statsRange) {
            Text("24 h").tag(HC2StatsRange.last24Hours)
            Text("7 d").tag(HC2StatsRange.last7Days)
            Text("30 d").tag(HC2StatsRange.last30Days)
            Text("1 y").tag(HC2StatsRange.lastYear)
        }
        .pickerStyle(.segmented)
        if statsLoading && statsCache[statsRange] == nil {
            ProgressView().frame(maxWidth: .infinity)
        } else if let statsError, statsCache[statsRange] == nil {
            Text(verbatim: statsError).foregroundStyle(Color.ipv64Red)
        } else if statsCache[statsRange] != nil {
            HealthcheckStatsRows(stats: statsCache[statsRange])
        }
    }

    @ViewBuilder
    private var incidentsContent: some View {
        if incidentsLoading && incidents == nil {
            Text("Loading...").foregroundStyle(.secondary)
        } else if let incidentsError {
            Text(verbatim: incidentsError).foregroundStyle(Color.ipv64Red)
        } else if let incidents {
            if incidents.isEmpty {
                Text("No incidents").foregroundStyle(.secondary)
            } else {
                ForEach(incidents) { HealthcheckIncidentRow(incident: $0) }
            }
        }
    }

    private var eventsSection: some View {
        Section("Events") {
            if events.isEmpty {
                Text("No events").foregroundStyle(.secondary)
            } else {
                ForEach(events) { HealthcheckEventRow(event: $0) }
            }
            if nextBefore != nil {
                Button(loadingMore ? "Loading..." : "Load more") { Task { await loadMore() } }
                    .disabled(loadingMore)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Loading

    /// Sequential (rate limit): detail → events → measurements (failure ignored).
    private func load() async {
        do {
            let loaded = try await ipv64Retrying { try await session.api.hc2.checks.get(token) }
            let page = try await ipv64Retrying { try await session.api.hc2.checks.events(token, limit: 50) }
            let list = (try? await ipv64Retrying { try await session.api.hc2.checks.measurements(token, limit: 100) }) ?? []
            if let all = try? await ipv64Retrying({ try await session.api.hc2.channels.list() }) { channels = all }
            detail = loaded
            pausedOverride = nil
            stateOverride = nil
            events = page.items
            nextBefore = page.meta?.hasMore == true ? page.meta?.nextBefore : nil
            measurements = list
            statsCache = [:]
            incidents = nil
            generation += 1
            failure = nil
        } catch is CancellationError {
        } catch {
            if detail == nil { failure = ErrorText(error) } else { self.error = ErrorText(error) }
        }
    }

    private func loadMore() async {
        guard let before = nextBefore else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page = try await ipv64Retrying { try await session.api.hc2.checks.events(token, limit: 50, before: before) }
            let known = Set(events.map(\.id))
            events += page.items.filter { !known.contains($0.id) }
            nextBefore = page.meta?.hasMore == true ? page.meta?.nextBefore : nil
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func loadStats() async {
        guard statsExpanded, detail != nil, statsCache[statsRange] == nil else { return }
        let range = statsRange
        statsLoading = true
        statsError = nil
        defer { statsLoading = false }
        do {
            statsCache[range] = try await ipv64Retrying { try await session.api.hc2.checks.stats(token, range: range) }
        } catch is CancellationError {
        } catch {
            statsError = ErrorText(error).message.nonBlank ?? String(localized: "Statistics could not be loaded")
        }
    }

    private func loadIncidents() async {
        guard incidentsExpanded, detail != nil, incidents == nil else { return }
        incidentsLoading = true
        incidentsError = nil
        defer { incidentsLoading = false }
        do {
            incidents = try await ipv64Retrying { try await session.api.hc2.incidents.list(check: token, limit: 20) }
        } catch is CancellationError {
        } catch {
            incidentsError = ErrorText(error).message.nonBlank ?? String(localized: "Incidents could not be loaded")
        }
    }

    // MARK: Actions

    private func togglePause() async {
        busy = true
        defer { busy = false }
        do {
            let updated = try await ipv64Retrying {
                paused ? try await session.api.hc2.checks.resume(token) : try await session.api.hc2.checks.pause(token)
            }
            pausedOverride = updated.paused ?? !paused
            stateOverride = updated.state ?? state
            router.reload()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func runNow() async {
        busy = true
        let result: HC2CheckRunResult
        do {
            result = try await ipv64Retrying { try await session.api.hc2.checks.run(token) }
            busy = false
        } catch {
            busy = false
            if !(error is CancellationError) { self.error = ErrorText(error) }
            return
        }
        guard result.queued != false, let nodeId = result.nodeID, let commandID = result.commandID else {
            message = result.queued == false ? String(localized: "Run not queued") : String(localized: "Run queued")
            return
        }
        waiting = String(localized: "Waiting for node \(detail?.nodeName ?? "")…")
        defer { waiting = nil }
        do {
            let list = try await pollUntil(
                interval: .seconds(3), max: .seconds(60),
                fetch: { try await session.api.hc2.nodes.commands(nodeId, limit: 20) },
                done: { $0.contains { $0.commandID == commandID && $0.doneAt != nil } })
            waiting = nil
            guard let entry = list?.first(where: { $0.commandID == commandID && $0.doneAt != nil }) else {
                message = String(localized: "Node has not reported back yet")
                return
            }
            router.reload()
            await load()
            var text = entry.ok == false ? String(localized: "Run failed") : String(localized: "Run finished: OK")
            if let output = commandOutputText(entry.output) { text += "\n" + output }
            message = text
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func askDelete() {
        confirm = ConfirmRequest(
            title: String(localized: "Delete healthcheck"),
            message: String(localized: "Delete \"\(detail?.name ?? "")\" and its history permanently?"),
            confirmLabel: String(localized: "Delete"), destructive: true
        ) { Task { await delete() } }
    }

    private func delete() async {
        busy = true
        defer { busy = false }
        do {
            try await ipv64Retrying { try await session.api.hc2.checks.delete(token) }
            router.reload()
            router.pop()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }
}
