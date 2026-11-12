import SwiftUI
import IPv64

/// Pushed from the list.
struct HealthcheckRoute: Hashable {
    let token: String
}

/// Healthcheck detail (API v2): status, actions, measuring points, configuration, statistics, incidents, events.
struct HealthcheckDetailView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let token: String
    /// Tells the list that this check changed (pause, resume, delete).
    let onChanged: () -> Void

    @State private var detail: HC2CheckDetail?
    @State private var pausedOverride: Bool?
    @State private var stateOverride: HC2Check.State?
    @State private var events: [HC2Event] = []
    @State private var nextBefore: Int?
    @State private var measurements: [HC2Measurement] = []
    @State private var channels: [HC2Channel] = []
    @State private var generation = 0
    @State private var busy = false
    @State private var isLoading = false
    @State private var loadingMore = false
    @State private var waiting: String?
    @State private var confirmDelete = false
    @State private var error: ErrorText?
    @State private var info: ErrorText?
    // Statistics and incidents load only when opened.
    @State private var statsRange = HC2StatsRange.last24Hours
    @State private var statsCache: [HC2StatsRange: HC2Stats] = [:]
    @State private var statsLoading = false
    @State private var statsError: String?
    @State private var eventsExpanded = false
    @State private var incidents: [HC2Incident]?
    @State private var incidentsLoading = false
    @State private var incidentsError: String?

    private struct StatsKey: Equatable { let range: HC2StatsRange, generation: Int }
    private struct IncidentsKey: Equatable { let generation: Int }

    private var paused: Bool { pausedOverride ?? detail?.paused ?? false }
    private var state: HC2Check.State? { stateOverride ?? detail?.state }
    private var runsOnNode: Bool { (detail?.execution ?? .online) != .online }

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(confirmDelete ? .clear : .orange)
        } else {
            content
        }
    }

    private var content: some View {
        List {
            if let detail {
                recent
                if HealthcheckStatusRows.hasContent(detail: detail, state: state) {
                    Section("Status") { HealthcheckStatusRows(detail: detail, state: state) }
                }
                actions(detail)
                if let sources = detail.sources, !sources.isEmpty {
                    Section("Measuring points") { HealthcheckSourceRows(sources: sources) }
                }
                if detail.type == .push, let push = detail.push {
                    Section("Push endpoints") { HealthcheckPushRows(push: push) }
                }
                Section("Configuration") { HealthcheckConfigRows(detail: detail, channels: channels) }
                if statsLoading || statsError != nil || statsCache[statsRange] != nil { statsSection }
                incidentsSection
                if !events.isEmpty { eventsSection }
            }
        }
        .overlay {
            if detail == nil && error == nil { ProgressView() }
        }
        // While loading or running an action everything is locked; the spinner sits in the toolbar.
        .disabled(busy || isLoading)
        .navigationTitle(detail?.name?.nonBlank ?? String(localized: "Healthcheck"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .refreshable { await load() }
        .task { await load() }
        .task(id: StatsKey(range: statsRange, generation: generation)) { await loadStats() }
        .task(id: IncidentsKey(generation: generation)) { await loadIncidents() }
        .alert("Delete healthcheck?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you really want to delete \"\(detail?.name ?? token)\"? Its history is deleted as well.")
        }
        .errorAlert($error)
        .errorAlert($info)
    }

    // MARK: Sections

    private func actions(_ detail: HC2CheckDetail) -> some View {
        Section {
            Button {
                Task { await togglePause() }
            } label: {
                Label(paused ? "Resume" : "Pause", systemImage: paused ? "play" : "pause")
            }
            Button {
                Task { await runNow() }
            } label: {
                Label("Run now", systemImage: "arrow.clockwise")
            }
            if let url = HcFormat.browserURL(type: detail.type, target: detail.target) {
                Button {
                    openURL(url)
                } label: {
                    Label("Open in browser", systemImage: "safari")
                }
            }
        } footer: {
            if let waiting { Text(verbatim: waiting) }
        }
        .tint(.primary)
    }

    @ViewBuilder private var recent: some View {
        if !measurements.isEmpty {
            Section("Recent checks") {
                StatusPillsBar(states: measurements.map { $0.status == .up ? .up : $0.status == .down ? .down : .pending },
                               noun: "checks")
            }
        } else if !events.isEmpty {
            Section("Recent events") {
                StatusPillsBar(states: events.map { HcFormat.eventState(kind: $0.kind?.rawValue, to: $0.toState) },
                               noun: "events")
            }
        }
    }

    private var statsSection: some View {
        Section("Statistics") {
            Picker("Range", selection: $statsRange) {
                Text("24 h").tag(HC2StatsRange.last24Hours)
                Text("7 d").tag(HC2StatsRange.last7Days)
                Text("30 d").tag(HC2StatsRange.last30Days)
                Text("1 y").tag(HC2StatsRange.lastYear)
            }
            .pickerStyle(.segmented)
            if let stats = statsCache[statsRange] {
                HealthcheckStatsRows(stats: stats)
            } else if let statsError {
                Text(verbatim: statsError).foregroundStyle(.red)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    private var incidentsSection: some View {
        Section {
            NavigationLink {
                HealthcheckIncidentsView(incidents: incidents ?? [])
            } label: {
                LabeledContent("Incidents") {
                    if incidentsError != nil {
                        Text("Unavailable")
                    } else if let incidents {
                        if incidents.isEmpty { Text("None") } else { Text(incidents.count.formatted()) }
                    } else {
                        ProgressView()
                    }
                }
            }
            .disabled(incidents?.isEmpty ?? true)
        }
    }

    private var eventsSection: some View {
        Section {
            if eventsExpanded {
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
        } header: {
            Button {
                withAnimation { eventsExpanded.toggle() }
            } label: {
                HStack {
                    Text("Events")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(eventsExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(eventsExpanded ? "Expanded" : "Collapsed")
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if busy || isLoading {
                ProgressView()
            } else {
                Button("Delete healthcheck", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    .tint(.red)
                    .disabled(detail == nil)
            }
        }
    }

    // MARK: Loading

    /// One after another (rate limit): detail, events, measurements and channels (the last two may fail silently).
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let api = session.api
        do {
            let loaded = try await ipv64Retrying { try await api.hc2.checks.get(token) }
            let page = try await ipv64Retrying { try await api.hc2.checks.events(token, limit: 50) }
            let list = (try? await ipv64Retrying { try await api.hc2.checks.measurements(token, limit: 100) }) ?? []
            if let all = try? await ipv64Retrying({ try await api.hc2.channels.list() }) { channels = all }
            detail = loaded
            pausedOverride = nil
            stateOverride = nil
            events = page.items
            nextBefore = page.meta?.hasMore == true ? page.meta?.nextBefore : nil
            measurements = list
            statsCache = [:]
            incidents = nil
            generation += 1
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func loadMore() async {
        guard let before = nextBefore else { return }
        loadingMore = true
        defer { loadingMore = false }
        let api = session.api
        do {
            let page = try await ipv64Retrying { try await api.hc2.checks.events(token, limit: 50, before: before) }
            let known = Set(events.map(\.id))
            events += page.items.filter { !known.contains($0.id) }
            nextBefore = page.meta?.hasMore == true ? page.meta?.nextBefore : nil
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func loadStats() async {
        guard detail != nil, statsCache[statsRange] == nil else { return }
        let range = statsRange
        let api = session.api
        statsLoading = true
        statsError = nil
        defer { statsLoading = false }
        do {
            statsCache[range] = try await ipv64Retrying { try await api.hc2.checks.stats(token, range: range) }
        } catch is CancellationError {
        } catch {
            statsError = ErrorText(error).message.nonBlank ?? String(localized: "Statistics could not be loaded")
        }
    }

    private func loadIncidents() async {
        guard detail != nil, incidents == nil else { return }
        let api = session.api
        incidentsLoading = true
        incidentsError = nil
        defer { incidentsLoading = false }
        do {
            incidents = try await ipv64Retrying { try await api.hc2.incidents.list(check: token, limit: 20) }
        } catch is CancellationError {
        } catch {
            incidentsError = ErrorText(error).message.nonBlank ?? String(localized: "Incidents could not be loaded")
        }
    }

    // MARK: Actions

    private func togglePause() async {
        busy = true
        defer { busy = false }
        let api = session.api
        let wasPaused = paused
        do {
            let updated = try await ipv64Retrying {
                wasPaused ? try await api.hc2.checks.resume(token) : try await api.hc2.checks.pause(token)
            }
            pausedOverride = updated.paused ?? !wasPaused
            stateOverride = updated.state ?? state
            onChanged()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    /// Online checks run at once; node checks are queued and polled every 3 s for up to 60 s.
    private func runNow() async {
        busy = true
        defer { busy = false; waiting = nil }
        let api = session.api
        do {
            let result = try await ipv64Retrying { try await api.hc2.checks.run(token) }
            guard result.queued != false, let nodeId = result.nodeID, let commandID = result.commandID else {
                let text = result.queued == false ? String(localized: "Run not queued") : String(localized: "Run queued")
                info = ErrorText(title: String(localized: "Run now"), message: result.detail?.nonBlank ?? text)
                return
            }
            waiting = String(localized: "Waiting for node \(detail?.nodeName ?? "")…")
            var entry: HC2Command?
            for _ in 0..<20 {
                try await Task.sleep(for: .seconds(3))
                let list = try await api.hc2.nodes.commands(nodeId, limit: 20)
                entry = list.first { $0.commandID == commandID && $0.doneAt != nil }
                if entry != nil { break }
            }
            guard let entry else {
                info = ErrorText(title: String(localized: "Run now"), message: String(localized: "Node has not reported back yet"))
                return
            }
            var text = entry.ok == false ? String(localized: "Run failed") : String(localized: "Run finished: OK")
            if let output = HcFormat.commandOutput(entry.output) { text += "\n" + output }
            info = ErrorText(title: String(localized: "Run now"), message: text)
            onChanged()
            waiting = nil
            await load()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func delete() async {
        busy = true
        defer { busy = false }
        let api = session.api
        do {
            try await ipv64Retrying { try await api.hc2.checks.delete(token) }
            onChanged()
            dismiss()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }
}
