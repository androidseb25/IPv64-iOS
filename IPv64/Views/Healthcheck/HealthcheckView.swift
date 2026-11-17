import SwiftUI
import IPv64

/// Healthchecks 2.0 of the account (API v2): compact rows with a status tag, status filter, swipe actions.
struct HealthcheckView: View {
    @Environment(Session.self) private var session
    @Environment(ConnectedNodes.self) private var nodes
    @Binding var popToRootTab: Tabs
    @State private var checks: [HC2Check]?
    @State private var status = HcStatusFilter.all
    @State private var exec = HcExecFilter.all
    @State private var busyTokens: Set<String> = []
    /// Removed at once while the delete request runs; back on failure.
    @State private var deletedTokens: Set<String> = []
    @State private var confirmDelete: HC2Check?
    @State private var showNew = false
    @State private var showTargetChoice = false
    /// Form to present once the target sheet has closed.
    @State private var chosenTarget: HealthcheckTarget?
    @State private var nodeForm: NodeFormTarget?
    @State private var monitorForm: NodeFormTarget?
    @State private var monitorData: [String: Monitor64ListData] = [:]
    @State private var nodeData: [String: NodeChecksData] = [:]
    @State private var confirmNodeDelete: NodeCheckRef?
    @State private var error: ErrorText?

    private struct NodeFormTarget: Identifiable {
        let id: String
    }

    private struct NodeCheckRef: Identifiable {
        let nodeId: String
        let check: Node64.Check
        var id: String { check.token }
    }

    /// Checks owned by a connected node are shown in its section instead.
    private var hiddenTokens: Set<String> { Set(nodeData.values.flatMap(\.owned).map(\.token)) }

    private var all: [HC2Check] {
        (checks ?? []).filter { !deletedTokens.contains($0.token) && !hiddenTokens.contains($0.token) }
    }

    /// Reachable nodes with the healthchecks module on.
    private var offeringNodes: [(id: String, name: String)] {
        nodes.ids.filter { nodeData[$0].map { $0.module == .on && $0.error == nil } ?? false }
            .map { ($0, nodes.name(of: $0)) }
    }

    /// Nodes where Monitor64 answered (module on).
    private var monitorNodes: [(id: String, name: String)] {
        nodes.ids.filter { monitorData[$0] != nil && monitorData[$0]?.error == nil }.map { ($0, nodes.name(of: $0)) }
    }

    private func hostRows(_ id: String) -> [Node64.Monitor64OverviewHost] {
        (monitorData[id]?.hosts ?? [])
            .filter { $0.uid != nil && $0.display.matches(status) }
            .sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }
    }

    private func nodeRows(_ id: String) -> [Node64.Check] {
        (nodeData[id]?.owned ?? [])
            .filter { !deletedTokens.contains($0.token) && status.matches($0.uiState) }
            .sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }
    }

    private var hasNodeRows: Bool { nodes.ids.contains { !nodeRows($0).isEmpty || !hostRows($0).isEmpty } }

    private var visible: [HC2Check] {
        all.filter { status.matches(Hc2StateUi.from($0)) && exec.matches($0.execution) }
            .sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }
    }

    private var showsExecFilter: Bool { all.contains { ($0.execution ?? .online) != .online } || exec != .all }

    var body: some View {
        if #available(iOS 26.0, *) {
            listView.setColorGradient(confirmDelete != nil || confirmNodeDelete != nil || showNew || showTargetChoice || nodeForm != nil || monitorForm != nil ? .clear : .orange)
        } else {
            listView
        }
    }

    private var listView: some View {
        List {
            Section {
                ForEach(visible) { check in
                    NavigationLink(value: HealthcheckRoute(token: check.token)) {
                        HealthcheckItemView(check: check, isBusy: busyTokens.contains(check.token))
                    }
                    .swipeActions {
                        swipeButtons(paused: check.paused == true,
                                     delete: { confirmDelete = check },
                                     setPaused: { paused in Task { await setPaused(check, paused) } })
                    }
                }
            } header: {
                if !nodes.ids.isEmpty && !visible.isEmpty { Text("Account") }
            }
            ForEach(nodes.ids, id: \.self) { nodeSection($0) }
            ForEach(nodes.ids, id: \.self) { monitorSection($0) }
        }
        .overlay { emptyState }
        .navigationTitle(Tabs.healthcheck.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HealthcheckRoute.self) { route in
            // The list re-reads once; the detail has already updated itself.
            HealthcheckDetailView(token: route.token) { Task { await load() } }
        }
        .navigationDestination(for: NodeCheckRoute.self) { route in
            NodeCheckDetailView(nodeId: route.nodeId, token: route.token) { Task { await loadNodes() } }
        }
        .navigationDestination(for: Monitor64HostRoute.self) { route in
            Monitor64HostDetailView(nodeId: route.nodeId, uid: route.uid) { Task { await loadNodes() } }
        }
        .toolbar { toolbar }
        .sheet(isPresented: $showNew) { HealthcheckFormView(token: nil) { Task { await load() } } }
        .sheet(isPresented: $showTargetChoice, onDismiss: presentChosen) {
            HealthcheckTargetSheet(nodes: offeringNodes, monitorNodes: monitorNodes) { chosenTarget = $0 }
        }
        .sheet(item: $nodeForm) { target in
            NodeCheckFormView(nodeId: target.id, token: nil) { Task { await loadNodes() } }
        }
        .sheet(item: $monitorForm) { target in
            Monitor64HostFormView(nodeId: target.id, uid: nil) { Task { await loadNodes() } }
        }
        .refreshable { await load() }
        .task { await load() }
        .task(id: nodes.ids) { await loadNodes() }
        .alert("Delete healthcheck?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
               presenting: confirmDelete) { check in
            Button("Delete", role: .destructive) { Task { await delete(check) } }
            Button("Cancel", role: .cancel) {}
        } message: { check in
            Text("Do you really want to delete \"\(check.name ?? check.token)\"? Its history is deleted as well.")
        }
        .alert("Delete healthcheck?", isPresented: Binding(get: { confirmNodeDelete != nil }, set: { if !$0 { confirmNodeDelete = nil } }),
               presenting: confirmNodeDelete) { ref in
            Button("Delete", role: .destructive) { Task { await deleteNodeCheck(ref) } }
            Button("Cancel", role: .cancel) {}
        } message: { ref in
            Text("Do you really want to delete \"\(ref.check.name ?? ref.check.token)\"? Its history is deleted as well.")
        }
        .errorAlert($error)
    }

    /// Icon only; delete is red.
    private func swipeButtons(paused: Bool, delete: @escaping () -> Void, setPaused: @escaping (Bool) -> Void) -> some View {
        Group {
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
                .tint(.red)
            if paused {
                Button("Resume", systemImage: "play") { setPaused(false) }
                    .tint(.green)
            } else {
                Button("Pause", systemImage: "pause") { setPaused(true) }
                    .tint(.teal)
            }
        }
        .labelStyle(.iconOnly)
    }

    @ViewBuilder private func nodeSection(_ id: String) -> some View {
        let name = nodes.name(of: id)
        if let data = nodeData[id] {
            if let message = data.error {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Node not reachable")
                        Text(verbatim: message).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
                    }
                } header: {
                    Text(verbatim: name)
                } footer: {
                    Text("Check the connection under More → Nodes.")
                }
            } else if data.module == .off {
                Section {
                } header: {
                    Text(verbatim: name)
                } footer: {
                    Text("Healthchecks module is off on this node")
                }
            } else if data.module == .on {
                let rows = nodeRows(id)
                if !rows.isEmpty {
                    Section {
                        ForEach(rows) { check in
                            NavigationLink(value: NodeCheckRoute(nodeId: id, token: check.token)) {
                                HealthcheckItemView(nodeCheck: check, isBusy: busyTokens.contains(check.token))
                            }
                            .swipeActions {
                                swipeButtons(paused: check.uiState == .paused,
                                             delete: { confirmNodeDelete = NodeCheckRef(nodeId: id, check: check) },
                                             setPaused: { paused in Task { await setNodePaused(id, check, paused) } })
                            }
                        }
                    } header: {
                        Text(verbatim: name)
                    }
                }
            }
        }
    }

    @ViewBuilder private func monitorSection(_ id: String) -> some View {
        let title = "\(nodes.name(of: id)) · Monitor64"
        if let message = monitorData[id]?.error {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monitor64 not available")
                    Text(verbatim: message).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
                }
            } header: {
                Text(verbatim: title)
            }
        }
        let rows = hostRows(id)
        if !rows.isEmpty {
            Section {
                ForEach(rows, id: \.uid) { host in
                    NavigationLink(value: Monitor64HostRoute(nodeId: id, uid: host.uid ?? "")) {
                        HealthcheckItemView(monitor64Host: host)
                    }
                }
            } header: {
                Text(verbatim: title)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Status", selection: $status) {
                    ForEach(HcStatusFilter.allCases, id: \.self) { filter in
                        Text(verbatim: "\(filter.label) (\(count(filter)))").tag(filter)
                    }
                }
                if showsExecFilter {
                    Picker("Runs on", selection: $exec) {
                        ForEach(HcExecFilter.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
            } label: {
                Label("Filter healthchecks", systemImage: status == .all && exec == .all
                      ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
            }
        }
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { addTapped() } label: { Label("New healthcheck", systemImage: "plus") }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if checks == nil {
            ProgressView("Loading healthchecks…")
        } else if visible.isEmpty && !hasNodeRows {
            ContentUnavailableView(all.isEmpty ? "No healthchecks yet" : "No matching healthchecks",
                                   systemImage: "bolt.heart")
        }
    }

    private func count(_ filter: HcStatusFilter) -> Int {
        all.filter { filter.matches(Hc2StateUi.from($0)) }.count
            + nodes.ids.flatMap { nodeData[$0]?.owned ?? [] }.filter { !deletedTokens.contains($0.token) && filter.matches($0.uiState) }.count
            + monitorData.values.flatMap(\.hosts).filter { $0.uid != nil && $0.display.matches(filter) }.count
    }

    /// First choose where the check runs when a reachable node offers checks.
    private func addTapped() {
        if offeringNodes.isEmpty && monitorNodes.isEmpty { showNew = true } else { showTargetChoice = true }
    }

    private func presentChosen() {
        guard let chosen = chosenTarget else { return }
        chosenTarget = nil
        switch chosen {
        case .account: showNew = true
        case .nodeCheck(let id): nodeForm = NodeFormTarget(id: id)
        case .monitor64Host(let id): monitorForm = NodeFormTarget(id: id)
        }
    }

    private func load() async {
        async let nodesLoad: Void = loadNodes()
        await loadAccount()
        await nodesLoad
    }

    /// Per node in parallel: status, module state, check list; a failing node never hides the account checks.
    /// Monitor64 loads independently of the checks: 404 = module off (no section), other errors show in its own group.
    private func loadNodes() async {
        let clients = nodes.ids.compactMap { id in nodes.client(for: id).map { (id, $0) } }
        var result: [String: NodeChecksData] = [:]
        var monitor: [String: Monitor64ListData] = [:]
        await withTaskGroup(of: (String, NodeChecksData, Monitor64ListData?).self) { group in
            for (id, client) in clients {
                group.addTask {
                    let data = await Self.loadNode(client)
                    // An unreachable node has no Monitor64 either.
                    return (id, data, data.error == nil ? await Self.loadMonitor(client) : nil)
                }
            }
            for await (id, data, hosts) in group {
                result[id] = data
                monitor[id] = hosts
            }
        }
        if !Task.isCancelled {
            nodeData = result
            monitorData = monitor
        }
    }

    private nonisolated static func loadMonitor(_ client: Node64) async -> Monitor64ListData? {
        do {
            return Monitor64ListData(hosts: try await client.monitor64.hosts.list())
        } catch {
            return isNodeNotFound(error) ? nil : Monitor64ListData(error: ErrorText.node(error).message)
        }
    }

    private nonisolated static func loadNode(_ client: Node64) async -> NodeChecksData {
        do {
            let module = nodeChecksModule(try await client.node.status().modules)
            guard module == .on else { return NodeChecksData(module: module) }
            return NodeChecksData(module: .on, checks: try await client.hc.checks.list())
        } catch {
            return NodeChecksData(module: .on, error: ErrorText.node(error).titledText)
        }
    }

    private func setNodePaused(_ nodeId: String, _ check: Node64.Check, _ paused: Bool) async {
        guard let client = nodes.client(for: nodeId) else { return }
        busyTokens.insert(check.token)
        defer { busyTokens.remove(check.token) }
        do {
            let updated = paused ? try await client.hc.checks.pause(check.token) : try await client.hc.checks.resume(check.token)
            if let index = nodeData[nodeId]?.checks.firstIndex(where: { $0.token == check.token }) {
                nodeData[nodeId]?.checks[index] = updated
            }
        } catch {
            self.error = .node(error)
        }
    }

    private func deleteNodeCheck(_ ref: NodeCheckRef) async {
        guard let client = nodes.client(for: ref.nodeId) else { return }
        _ = withAnimation { deletedTokens.insert(ref.check.token) }
        do {
            try await client.hc.checks.delete(ref.check.token)
            nodeData[ref.nodeId]?.checks.removeAll { $0.token == ref.check.token }
        } catch {
            _ = withAnimation { deletedTokens.remove(ref.check.token) }
            self.error = .node(error)
        }
    }

    private func loadAccount() async {
        let api = session.api
        do {
            checks = try await ipv64Retrying { try await api.hc2.checks.list() }
        } catch is CancellationError {
        } catch {
            if checks == nil { checks = [] }
            self.error = ErrorText(error)
        }
    }

    private func setPaused(_ check: HC2Check, _ paused: Bool) async {
        let api = session.api
        busyTokens.insert(check.token)
        defer { busyTokens.remove(check.token) }
        do {
            let updated = try await ipv64Retrying {
                paused ? try await api.hc2.checks.pause(check.token) : try await api.hc2.checks.resume(check.token)
            }
            if let index = checks?.firstIndex(where: { $0.token == check.token }) { checks?[index] = updated }
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func delete(_ check: HC2Check) async {
        let api = session.api
        _ = withAnimation { deletedTokens.insert(check.token) }
        do {
            try await ipv64Retrying { try await api.hc2.checks.delete(check.token) }
            checks?.removeAll { $0.token == check.token }
        } catch {
            _ = withAnimation { deletedTokens.remove(check.token) }
            self.error = ErrorText(error)
        }
    }
}

#Preview { NavigationStack { HealthcheckView(popToRootTab: .constant(.healthcheck)) } }
