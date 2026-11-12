import SwiftUI
import IPv64

/// Detail of a check of a connected node (direct access): same structure as the account check detail.
struct NodeCheckDetailView: View {
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(\.dismiss) private var dismiss

    let nodeId: String
    let token: String
    /// Tells the list that this check changed (pause, resume, delete, edit).
    let onChanged: () -> Void

    @State private var check: Node64.Check?
    @State private var events: [Node64.CheckEvent] = []
    @State private var hasMoreEvents = false
    @State private var measurements: [Node64.CheckMeasurement] = []
    @State private var generation = 0
    @State private var busy = false
    @State private var isLoading = false
    @State private var loadingMore = false
    @State private var confirmDelete = false
    @State private var showEdit = false
    @State private var error: ErrorText?
    @State private var statsRange = Node64.CheckStatsRange.last24Hours
    @State private var statsCache: [Node64.CheckStatsRange: Node64.CheckStats] = [:]
    @State private var statsError: String?
    @State private var eventsExpanded = false
    @State private var incidents: [Node64.CheckIncident]?
    @State private var incidentsError: String?

    private static let pageSize = 50

    private struct StatsKey: Equatable { let range: Node64.CheckStatsRange, generation: Int }

    private var client: Node64? { nodes.client(for: nodeId) }
    private var paused: Bool { check?.paused == true || check?.state?.state == .paused }
    private var editable: Bool { check?.type.map(nodeCheckTypes.contains) ?? false }

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(confirmDelete || showEdit ? .clear : .orange)
        } else {
            content
        }
    }

    private var content: some View {
        List {
            if let check {
                recent
                if NodeCheckStatusRows.hasContent(check) {
                    Section("Status") { NodeCheckStatusRows(check: check) }
                }
                actions
                if check.type == .push, let url = check.pushURL?.nonBlank { pushSection(url) }
                Section("Configuration") { NodeCheckConfigRows(check: check) }
                if statsCache[statsRange] != nil || statsError != nil { statsSection }
                incidentsSection
                if !events.isEmpty { eventsSection }
            }
        }
        .overlay {
            if check == nil && error == nil { ProgressView() }
        }
        .disabled(busy || isLoading)
        .navigationTitle(check?.name?.nonBlank ?? String(localized: "Healthcheck"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .refreshable { await load() }
        .task { await load() }
        .task(id: StatsKey(range: statsRange, generation: generation)) { await loadStats() }
        .sheet(isPresented: $showEdit) {
            NodeCheckFormView(nodeId: nodeId, token: token) {
                onChanged()
                Task { await load() }
            }
        }
        .alert("Delete healthcheck?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you really want to delete \"\(check?.name ?? token)\"? Its history is deleted as well.")
        }
        .errorAlert($error)
    }

    // MARK: Sections

    private var actions: some View {
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
        }
        .tint(.primary)
    }

    private func pushSection(_ url: String) -> some View {
        Section("Push endpoints") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Push URL").font(.subheadline).foregroundStyle(.secondary)
                Text(verbatim: url).font(.callout.monospaced()).textSelection(.enabled)
                HStack(spacing: 16) {
                    Button("Copy", systemImage: "doc.on.doc") { Clipboard.copy(url, sensitive: true) }
                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                }
                .buttonStyle(.borderless)
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder private var recent: some View {
        if !measurements.isEmpty {
            Section("Recent checks") {
                StatusPillsBar(states: measurements.map { $0.status == .up ? .up : $0.status == .down ? .down : .pending },
                               noun: "checks")
            }
        } else if !events.isEmpty {
            Section("Recent events") {
                StatusPillsBar(states: events.map { HcFormat.eventState(kind: $0.kind, to: $0.to) }, noun: "events")
            }
        }
    }

    private var statsSection: some View {
        Section("Statistics") {
            Picker("Range", selection: $statsRange) {
                Text("1 h").tag(Node64.CheckStatsRange.lastHour)
                Text("24 h").tag(Node64.CheckStatsRange.last24Hours)
                Text("7 d").tag(Node64.CheckStatsRange.last7Days)
                Text("30 d").tag(Node64.CheckStatsRange.last30Days)
                Text("1 y").tag(Node64.CheckStatsRange.lastYear)
            }
            .pickerStyle(.segmented)
            if let stats = statsCache[statsRange] {
                NodeCheckStatsRows(stats: stats)
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
                NodeCheckIncidentsView(incidents: incidents ?? [])
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
                ForEach(events) { NodeCheckEventRow(event: $0) }
                if hasMoreEvents {
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
            Button("Edit", systemImage: "pencil") { showEdit = true }
                .disabled(check == nil || !editable || busy || isLoading)
        }
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if busy || isLoading {
                ProgressView()
            } else {
                Button("Delete healthcheck", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    .tint(.red)
                    .disabled(check == nil)
            }
        }
    }

    // MARK: Loading

    /// One after another; measurements, events and incidents may fail silently (the check itself must load).
    private func load() async {
        guard let client else {
            error = ErrorText(title: String(localized: "Node not reachable"),
                              message: String(localized: "No local access stored for this node."))
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await client.hc.checks.get(token)
            let page = (try? await client.hc.checks.events(token, limit: Self.pageSize)) ?? []
            let list = (try? await client.hc.checks.measurements(token, limit: 100)) ?? []
            let incidentList = try? await client.hc.checks.incidents(token, limit: 20)
            check = loaded
            events = page
            hasMoreEvents = page.count >= Self.pageSize
            measurements = list
            incidents = incidentList
            incidentsError = incidentList == nil ? String(localized: "Incidents could not be loaded") : nil
            statsCache = [:]
            generation += 1
        } catch is CancellationError {
        } catch {
            self.error = .node(error)
        }
    }

    private func loadMore() async {
        guard let client, let before = events.last?.id else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page = try await client.hc.checks.events(token, limit: Self.pageSize, before: before)
            let known = Set(events.map(\.id))
            events += page.filter { !known.contains($0.id) }
            hasMoreEvents = page.count >= Self.pageSize
        } catch is CancellationError {
        } catch {
            self.error = .node(error)
        }
    }

    private func loadStats() async {
        guard let client, check != nil, statsCache[statsRange] == nil else { return }
        let range = statsRange
        statsError = nil
        do {
            statsCache[range] = try await client.hc.checks.stats(token, range: range)
        } catch is CancellationError {
        } catch {
            statsError = ErrorText.node(error).message.nonBlank ?? String(localized: "Statistics could not be loaded")
        }
    }

    // MARK: Actions

    private func togglePause() async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        do {
            check = paused ? try await client.hc.checks.resume(token) : try await client.hc.checks.pause(token)
            onChanged()
        } catch is CancellationError {
        } catch {
            self.error = .node(error)
        }
    }

    private func runNow() async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        do {
            try await client.hc.checks.run(token)
            onChanged()
        } catch is CancellationError {
            return
        } catch {
            self.error = .node(error)
            return
        }
        await load()
    }

    private func delete() async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        do {
            try await client.hc.checks.delete(token)
            onChanged()
            dismiss()
        } catch is CancellationError {
        } catch {
            self.error = .node(error)
        }
    }
}
