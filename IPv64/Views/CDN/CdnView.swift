import SwiftUI
import IPv64

/// CDN64: the CDN64 names of every connected proxy node. Tab root without a proxy node explains how to get one;
/// pushed from Proxy64 otherwise. "+" enables CDN64 for a proxy host.
struct CdnView: View {
    @Environment(ConnectedNodes.self) private var nodes
    @Binding var popToRootTab: Tabs
    @State private var nodeData: [ProxyNodeData]?
    @State private var enableChoices: [CdnHostChoice]?
    @State private var error: ErrorText?

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(enableChoices != nil ? .clear : .orange)
        } else { content }
    }

    private var content: some View {
        Group {
            if nodes.proxyIds.isEmpty {
                ContentUnavailableView {
                    Label("CDN64 needs a node", systemImage: "cloud")
                } description: {
                    Text("CDN64 runs on a Node64 with the Proxy64 module. Connect one under More → Nodes.")
                }
            } else {
                List {
                    ForEach(nodeData ?? []) { data in
                        CdnNodeSection(node: data) { id in Task { await reload(node: id) } }
                    }
                }
                .overlay { if nodeData == nil { ProgressView("Loading CDN64…") } }
                .refreshable { await load() }
                .task(id: nodes.proxyIds) { await load() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { enable() } label: { Label("Enable CDN64 for a proxy host", systemImage: "plus") }
                            .disabled(nodeData == nil)
                    }
                }
                .sheet(isPresented: Binding(get: { enableChoices != nil }, set: { if !$0 { enableChoices = nil } })) {
                    CdnEnableFlow(choices: enableChoices ?? []) { choice, mode, healthcheck in
                        if let failure = await nodes.enableCdn64(choice, mode: mode, healthcheck: healthcheck) { error = failure }
                        await reload(node: choice.nodeId)
                    }
                }
                .errorAlert($error)
            }
        }
        .navigationTitle(Tabs.cdn.labelNew)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func enable() {
        let choices = (nodeData ?? []).flatMap(\.cdnChoices)
        if (nodeData ?? []).allSatisfy({ $0.error != nil }) {
            error = ProxyLogic.noNodeError
        } else {
            enableChoices = choices
        }
    }

    private func load() async {
        let loaded = await nodes.loadProxyNodes(withHosts: true)
        if !Task.isCancelled { nodeData = loaded }
    }

    private func reload(node id: String) async {
        let fresh = await nodes.loadProxyNode(id, withHosts: true)
        if let index = nodeData?.firstIndex(where: { $0.id == id }) { nodeData?[index] = fresh } else { await load() }
    }
}

/// CDN64 names of one proxy node: server count, sync error and the names with their mode; a name opens its host.
private struct CdnNodeSection: View {
    let node: ProxyNodeData
    let onChanged: (String) -> Void

    var body: some View {
        Section(node.name) {
            if let error = node.error {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: error.title)
                    Text(verbatim: error.message).font(.subheadline).foregroundStyle(.secondary)
                    Text("Check the connection under More → Nodes.").font(.subheadline).foregroundStyle(.secondary)
                }
            } else if let status = node.online {
                let edges = status.edges ?? []
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: ProxyLogic.serversText(connected: edges.filter { $0.connected == true }.count, total: edges.count))
                    if let sync = status.syncError?.nonBlank { Text(verbatim: sync).font(.subheadline).foregroundStyle(.secondary) }
                }
                ForEach(Array((status.names ?? []).enumerated()), id: \.offset) { _, name in
                    if let hostID = name.hostID {
                        NavigationLink {
                            ProxyHostEditView(route: ProxyHostRoute(nodeId: node.id, hostId: hostID)) { onChanged(node.id) }
                        } label: { nameRow(name) }
                    } else {
                        nameRow(name)
                    }
                }
                if (status.names ?? []).isEmpty {
                    Text("No names in CDN64 yet.").foregroundStyle(.secondary)
                }
            } else {
                Text("CDN64 status not available.").foregroundStyle(.secondary)
            }
        }
    }

    private func nameRow(_ name: Node64.CDNOnlineName) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name.name?.nonBlank ?? "–").font(.headline).lineLimit(1)
                if let check = name.check?.nonBlank {
                    Text("Check: \(check)").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ProxyTag(tag: ProxyLogic.Tag(text: ProxyLogic.modeShort(name.mode), tone: .gray))
        }
    }
}
