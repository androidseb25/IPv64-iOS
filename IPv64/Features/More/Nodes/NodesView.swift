import SwiftUI
import IPv64

/// Nodes list (spec 04 §2): cloud-linked nodes + directly connected nodes.
struct NodesView: View {
    @Environment(Session.self) private var session
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(Router.self) private var router

    @State private var cloud: [HC2Node] = []
    @State private var loaded = false
    @State private var planReason: String?
    @State private var error: ErrorText?
    @State private var message: ErrorText?
    @State private var sheet: NodesSheet?
    @State private var openDirectAfterDismiss = false
    @State private var wait: WaitRequest?

    private struct WaitRequest: Equatable {
        let id = UUID()
        let before: [String: Date?]
    }

    private enum NodesSheet: String, Identifiable {
        case add, link
        var id: String { rawValue }
    }

    private struct LoadKey: Equatable {
        let reload: Int
        let account: Int
    }

    private var directIds: [String] {
        let cloudIds = Set(cloud.map(\.nodeID))
        return nodes.ids.filter { !cloudIds.contains($0) }
    }

    var body: some View {
        content
            .navigationTitle("Nodes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add node", systemImage: "plus") { sheet = .add }
                }
            }
            .task(id: LoadKey(reload: router.reloadToken, account: session.accountRevision)) { await load(showSpinner: !loaded) }
            .task(id: wait?.id) { await waitForNode() }
            .refreshable { await load(showSpinner: false) }
            .onAppear { nodes.refresh() }
            .errorAlert($error) { Task { await load(showSpinner: true) } }
            .errorAlert($message)
            .sheet(item: $sheet, onDismiss: showDirectAccessIfRequested) { sheet in
                switch sheet {
                case .add: AddNodeSheet(planBlocked: planReason != nil, onLink: { self.sheet = .link }, onDirect: {
                    openDirectAfterDismiss = true
                    self.sheet = nil
                })
                case .link: NodeLinkSheet { wait = WaitRequest(before: $0) }
                }
            }
            .loadingOverlay(!loaded && error == nil && planReason == nil)
    }

    @ViewBuilder private var content: some View {
        let direct = directIds
        if loaded && cloud.isEmpty && direct.isEmpty {
            if let planReason {
                NotAvailableView(feature: "Nodes", reason: planReason)
            } else {
                ContentUnavailableView("No nodes yet.", systemImage: "point.3.connected.trianglepath.dotted",
                                       description: Text("Tap + to link a node with the code your Node64 shows under \"ipv64 link\", or connect to one directly."))
            }
        } else {
            List {
                if wait != nil { waitingSection }
                Section {
                    ForEach(cloud) { node in
                        NavigationLink(value: Route.nodeDetail(nodeId: node.nodeID)) { CloudNodeRow(node: node) }
                    }
                    ForEach(direct, id: \.self) { id in
                        NavigationLink(value: Route.nodeDetail(nodeId: id)) { DirectNodeRow(nodeId: id, name: nodes.name(of: id), url: nodes.access(for: id)?.url) }
                    }
                }
            }
        }
    }

    private var waitingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Waiting for the node").font(.headline)
                ProgressView().progressViewStyle(.linear)
                Text("The node fetches its token itself. This usually takes less than a minute.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func showDirectAccessIfRequested() {
        guard openDirectAfterDismiss else { return }
        openDirectAfterDismiss = false
        router.sheet = .directAccess(nodeId: nil)
    }

    private func load(showSpinner: Bool) async {
        do {
            cloud = try await ipv64Retrying { try await session.api.hc2.nodes.list() }
            planReason = nil
            loaded = true
        } catch is CancellationError {
            return
        } catch {
            guard let apiError = error as? IPv64Error, apiError.isPlanRestricted else {
                if !(error is CancellationError) { self.error = ErrorText(error) }
                loaded = true
                return
            }
            cloud = []
            planReason = apiError.planRestrictionText
            loaded = true
        }
        nodes.refresh()
    }

    /// Polls the list every 5 s up to 60 s until a new node (or a changed `linkedAt`) appears.
    private func waitForNode() async {
        guard let request = wait else { return }
        defer { wait = nil }
        do {
            let found = try await pollUntil(
                interval: .seconds(5), max: .seconds(60),
                onEach: { cloud = $0 },
                fetch: { try await session.api.hc2.nodes.list() },
                done: { list in
                    list.contains { node in request.before[node.nodeID].map { $0 != node.linkedAt } ?? true }
                })
            if found == nil {
                message = ErrorText(title: String(localized: "Node not visible yet"),
                                    message: String(localized: "The node has not fetched its token yet. Make sure it is online and has internet access, then pull down to refresh."))
            }
        } catch is CancellationError {
            return
        } catch {
            self.error = ErrorText(error)
        }
        nodes.refresh()
    }
}

private struct CloudNodeRow: View {
    let node: HC2Node

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: Formatters.nodeName(node.name, nodeId: node.nodeID))
                Text(verbatim: cloudNodeSubtitle(location: node.location, version: node.version, lastSeen: node.lastSeen,
                                                 remote: node.remoteMgmt?.rawValue, conflicts: node.conflicts))
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            if node.online == true { StatusChip("Online", color: .ipv64Green) } else { StatusChip("Offline", color: .ipv64Gray) }
        }
    }
}

private struct DirectNodeRow: View {
    let nodeId: String
    let name: String
    let url: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                Text(verbatim: directNodeSubtitle(url: url)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            StatusChip("Direct", color: .ipv64Blue)
        }
    }
}

/// "Add node" sheet: two rows, no confirm button.
private struct AddNodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let planBlocked: Bool
    let onLink: () -> Void
    let onDirect: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Button(action: onLink) {
                    ListRow("Link node",
                            subtitle: planBlocked ? "Not available on your plan" : "Link it to your account with the code from \"ipv64 link\"",
                            systemImage: "link")
                }
                .disabled(planBlocked)
                Button(action: onDirect) {
                    ListRow("Connect directly", subtitle: "By IP or link and API key, without linking", systemImage: "network")
                }
            }
            .navigationTitle("Add node")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
