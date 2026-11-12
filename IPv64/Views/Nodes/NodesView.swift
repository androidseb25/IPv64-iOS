import SwiftUI
import IPv64

/// Nodes (pushed from More): cloud-linked nodes of the account and nodes connected directly from this device.
struct NodesView: View {
    static let route = "settings.nodes"

    @Environment(Session.self) private var session
    @Environment(ConnectedNodes.self) private var nodes
    @State private var cloud: [HC2Node]?
    /// Set when the plan does not include nodes (HTTP 403).
    @State private var planReason: String?
    @State private var sheet: NodesSheet?
    @State private var confirmForget: String?
    @State private var error: ErrorText?

    enum NodesSheet: String, Identifiable {
        case add, direct
        var id: String { rawValue }
    }

    private var cloudNodes: [HC2Node] {
        (cloud ?? []).sorted {
            NodesLogic.nodeName($0.name, nodeId: $0.nodeID)
                .localizedStandardCompare(NodesLogic.nodeName($1.name, nodeId: $1.nodeID)) == .orderedAscending
        }
    }

    /// Directly connected nodes that are not linked to the account (linked ones show as cloud rows).
    private var directIds: [String] {
        let cloudIds = Set((cloud ?? []).map(\.nodeID))
        return nodes.ids.filter { !cloudIds.contains($0) }
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            listView.setColorGradient(sheet != nil || confirmForget != nil ? .clear : .orange)
        } else {
            listView
        }
    }

    private var listView: some View {
        List {
            ForEach(cloudNodes) { CloudNodeRow(node: $0) }
            ForEach(directIds, id: \.self) { id in
                DirectNodeRow(name: nodes.name(of: id), host: NodesLogic.directSubtitle(url: LocalNodeStore.url(id)))
                    .swipeActions {
                        Button("Forget access", systemImage: "trash", role: .destructive) { confirmForget = id }
                            .labelStyle(.iconOnly)
                            .tint(.red)
                    }
            }
        }
        .overlay { emptyState }
        .navigationTitle("Nodes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = .add } label: { Label("Add node", systemImage: "plus") }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .onAppear { nodes.refresh() }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            // Switching the item closes this sheet and opens the form.
            case .add: AddNodeSheet { self.sheet = .direct }
            case .direct: NodeLocalSheet()
            }
        }
        .alert("Forget access?", isPresented: Binding(get: { confirmForget != nil }, set: { if !$0 { confirmForget = nil } }),
               presenting: confirmForget) { id in
            Button("Forget", role: .destructive) { forget(id) }
            Button("Cancel", role: .cancel) {}
        } message: { id in
            Text("The address and API key of \"\(nodes.name(of: id))\" are removed from this device. The node itself is not changed.")
        }
        .errorAlert($error)
    }

    @ViewBuilder private var emptyState: some View {
        if cloud == nil && directIds.isEmpty {
            ProgressView("Loading nodes…")
        } else if cloudNodes.isEmpty && directIds.isEmpty {
            if let planReason {
                ContentUnavailableView("Nodes not available", systemImage: "point.3.connected.trianglepath.dotted",
                                       description: Text(planReason))
            } else {
                ContentUnavailableView {
                    Label("No nodes yet", systemImage: "point.3.connected.trianglepath.dotted")
                } description: {
                    Text("Tap + to link a node with the code your Node64 shows under \"ipv64 link\", or connect to one directly.")
                } actions: {
                    Button("Add node") { sheet = .add }
                }
            }
        }
    }

    private func load() async {
        let api = session.api
        do {
            cloud = try await ipv64Retrying { try await api.hc2.nodes.list() }
            planReason = nil
        } catch is CancellationError {
        } catch let apiError as IPv64Error where apiError.statusCode == 403 {
            cloud = []
            if case .api(let problem) = apiError, let detail = problem.detail.nonBlank {
                planReason = detail
            } else {
                planReason = String(localized: "This feature is not available on your plan.")
            }
        } catch {
            if cloud == nil { cloud = [] }
            self.error = ErrorText(error)
        }
        nodes.refresh()
    }

    private func forget(_ id: String) {
        LocalNodeStore.remove(id)
        withAnimation { nodes.refresh() }
    }
}

private struct CloudNodeRow: View {
    let node: HC2Node

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NodesLogic.nodeName(node.name, nodeId: node.nodeID))
                    .font(.headline)
                    .lineLimit(1)
                if let meta = NodesLogic.cloudMeta(location: node.location, version: node.version, lastSeen: node.lastSeen) {
                    Text(meta)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(NodesLogic.remoteLine(node.remoteMgmt?.rawValue, conflicts: node.conflicts))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if node.online == true {
                HealthcheckTag(text: "Online", color: .green)
            } else {
                HealthcheckTag(text: "Offline", color: .gray)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DirectNodeRow: View {
    let name: String
    let host: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                Text(host)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HealthcheckTag(text: "Direct", color: .blue)
        }
        .accessibilityElement(children: .combine)
    }
}

/// "Add node": link with a code (later step) or connect directly.
private struct AddNodeSheet: View {
    let onDirect: () -> Void

    var body: some View {
        DynDNSSheet(title: "Add node") {
            Section {
                option("Link node", subtitle: "Link it to your account with the code from \"ipv64 link\"", systemImage: "link") {}
                    .disabled(true)
            } footer: {
                Text("Coming next")
            }
            Section {
                option("Connect directly", subtitle: "By IP or link and API key, without linking", systemImage: "network",
                       action: onDirect)
            }
        }
        .presentationDetents([.medium])
    }

    private func option(_ title: LocalizedStringKey, subtitle: LocalizedStringKey, systemImage: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
        .tint(.primary)
    }
}

#Preview {
    NavigationStack { NodesView() }
        .environment(Session())
        .environment(ConnectedNodes())
}
