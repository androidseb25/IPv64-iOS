import SwiftUI
import IPv64

/// Stored result of one connected node (spec 02 B1.3).
struct NodeChecksData: Sendable {
    var module: NodeChecksModule
    var checks: [Node64.Check] = []
    var error: String?
}

/// Healthcheck list (tab root, sidebar; spec 02 B1): account checks first, then one section per connected node.
struct HealthcheckListView: View {
    @Environment(Session.self) private var session
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(Router.self) private var router

    @State private var allChecks: [HC2Check] = []
    @State private var loaded = false
    @State private var loadedRevision: Int?
    @State private var nodeData: [String: NodeChecksData] = [:]
    @State private var query = ""
    @State private var status: HcStatusFilter = .all
    @State private var exec: HcExecFilter = .all
    @State private var error: ErrorText?
    @State private var failure: ErrorText?
    @State private var showTargetChoice = false

    private struct LoadKey: Equatable {
        let revision: Int
        let reload: Int
        let nodeIds: [String]
    }

    private var hiddenTokens: Set<String> {
        Set(nodeData.values.flatMap(\.checks).filter { isNodeOwned($0.owner) }.map(\.token))
    }

    private var checks: [HC2Check] { accountChecks(allChecks, hiddenTokens: hiddenTokens) }

    private var visible: [HC2Check] { healthcheckVisible(checks, status: status, exec: exec, query: query) }

    private var anyNodeChecks: Bool {
        nodeData.values.contains { $0.error == nil && $0.checks.contains { isNodeOwned($0.owner) } }
    }

    var body: some View {
        @Bindable var router = router
        Group {
            if !loaded {
                if let failure {
                    ErrorStateView(title: failure.title, message: failure.message) {
                        self.failure = nil
                        Task { await reload() }
                    }
                } else {
                    LoadingView()
                }
            } else {
                List(selection: $router.selection) {
                    if !visible.isEmpty {
                        Section {
                            ForEach(visible) { check in
                                NavigationLink(value: Route.healthcheckDetail(token: check.token)) {
                                    HealthcheckRow(check: check)
                                }
                            }
                        }
                    }
                    ForEach(nodes.ids, id: \.self) { nodeSection($0) }
                    if visible.isEmpty && !anyNodeChecks {
                        Section {
                            Text(checks.isEmpty ? "No healthchecks yet." : "No healthchecks match.")
                                .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        }
                    }
                    Section {} footer: {
                        Text("Classic healthchecks are managed at ipv64.net").frame(maxWidth: .infinity)
                    }
                }
                .searchable(text: $query, prompt: "Search")
                .refreshable { await reload() }
            }
        }
        .navigationTitle("Healthchecks")
        .toolbar { toolbar }
        .task(id: LoadKey(revision: session.accountRevision, reload: router.reloadToken, nodeIds: nodes.ids)) {
            if loadedRevision != session.accountRevision {
                loaded = false
                allChecks = []
                nodeData = [:]
            }
            await reload()
        }
        .errorAlert($error) { Task { await reload() } }
        .sheet(isPresented: $showTargetChoice) {
            HealthcheckTargetSheet(nodes: offeringNodes, onAccount: { router.push(.healthcheckForm(token: nil)) },
                                   onNode: { router.push(.nodeCheckEdit(nodeId: $0, token: nil)) })
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Filter", systemImage: AppSymbol.filter(active: status != .all || exec != .all)) {
                Picker("Status", selection: $status) {
                    ForEach(HcStatusFilter.allCases, id: \.self) { filter in
                        Text(verbatim: "\(filter.label) \(count(filter))").tag(filter)
                    }
                }
                if showsExecFilter(checks, current: exec) {
                    Picker("Runs on", selection: $exec) {
                        ForEach(HcExecFilter.allCases, id: \.self) { filter in
                            Text(verbatim: "\(filter.label) \(checks.filter { filter.matches($0.execution) }.count)").tag(filter)
                        }
                    }
                }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("New healthcheck", systemImage: "plus") { addTapped() }
        }
    }

    private func count(_ filter: HcStatusFilter) -> Int {
        filter == .all ? checks.count : healthcheckStatusCount(checks, filter)
    }

    // MARK: Nodes

    @ViewBuilder
    private func nodeSection(_ id: String) -> some View {
        let name = nodes.name(of: id)
        if let data = nodeData[id] {
            if let error = data.error {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Node not reachable")
                        Text(verbatim: error).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
                    }
                } header: { Text(verbatim: name) } footer: { Text("Check the connection under More → Nodes.") }
            } else if data.module == .off {
                Section {} header: { Text(verbatim: name) } footer: { Text("Healthchecks module is off on this node") }
            } else if data.module == .on {
                let rows = nodeChecksVisible(data.checks, status: status, query: query)
                if !rows.isEmpty {
                    Section {
                        ForEach(rows) { check in
                            NavigationLink(value: Route.nodeCheckDetail(nodeId: id, token: check.token)) {
                                NodeCheckRow(check: check)
                            }
                        }
                    } header: { Text(verbatim: name) }
                }
            }
        }
    }

    /// Nodes offering checks (module on/unknown); the sheet additionally needs no error.
    private var offeringNodes: [(id: String, name: String)] {
        nodes.ids.filter { id in
            guard let data = nodeData[id] else { return true }
            return data.module == .on && data.error == nil
        }
        .map { ($0, nodes.name(of: $0)) }
    }

    private func addTapped() {
        let offers = nodes.ids.contains { id in nodeData[id].map { $0.module == .on } ?? true }
        if offers { showTargetChoice = true } else { router.push(.healthcheckForm(token: nil)) }
    }

    // MARK: Loading

    private func reload() async {
        async let nodesLoad: Void = loadNodes()
        await loadChecks()
        await nodesLoad
    }

    private func loadChecks() async {
        do {
            let list = try await ipv64Retrying { try await session.api.hc2.checks.list() }
            allChecks = list
            loadedRevision = session.accountRevision
            failure = nil
            loaded = true
        } catch is CancellationError {
        } catch {
            if loaded { self.error = ErrorText(error) } else { failure = ErrorText(error) }
        }
    }

    /// Per node in parallel: status → module state → check list; errors keep the account rows visible.
    private func loadNodes() async {
        let clients = nodes.ids.compactMap { id in nodes.client(for: id).map { (id, $0) } }
        var result: [String: NodeChecksData] = [:]
        await withTaskGroup(of: (String, NodeChecksData).self) { group in
            for (id, client) in clients {
                group.addTask { (id, await Self.loadNode(client)) }
            }
            for await (id, data) in group { result[id] = data }
        }
        if !Task.isCancelled { nodeData = result }
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
}
