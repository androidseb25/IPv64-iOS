import SwiftUI
import IPv64

/// Proxy64 tab: usage, entry to CDN64, proxy hosts per connected node.
struct ProxyView: View {
    @Environment(Session.self) private var session
    @Environment(ConnectedNodes.self) private var nodes
    @Binding var popToRootTab: Tabs
    @State private var groups: [ProxyNodeData]?
    @State private var cloudNames: [String]?
    @State private var usage: Me.Usage?
    @State private var sheet: ProxySheet?
    @State private var newHost: ProxyHostRoute?
    @State private var error: ErrorText?

    var body: some View {
        if #available(iOS 26.0, *) {
            listView.setColorGradient(sheet != nil ? .clear : .orange)
        } else { listView }
    }

    private var listView: some View {
        List {
            if groups != nil {
                ProxyUsageSection(usage: usage, quota: groups?.lazy.compactMap { $0.online?.quota }.first)
                cdnSection
                ForEach(groups ?? []) { group in
                    Section(group.name) {
                        if let error = group.error {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: error.title)
                                Text(verbatim: error.message).font(.subheadline).foregroundStyle(.secondary)
                                Text("Check the connection under More → Nodes.").font(.subheadline).foregroundStyle(.secondary)
                            }
                        } else if group.hosts.isEmpty {
                            Text("No hosts.").foregroundStyle(.secondary)
                        }
                        ForEach(group.hosts) { host in
                            NavigationLink(value: ProxyHostRoute(nodeId: group.id, hostId: host.id)) {
                                ProxyHostRow(host: host, cdn: group.cdn[host.id], edges: group.online?.edges ?? [])
                            }
                            .swipeActions {
                                if group.cdn[host.id] == nil && group.error == nil {
                                    Button("Enable CDN64", systemImage: "cloud") {
                                        sheet = .enableCdn(CdnHostChoice(nodeId: group.id, nodeName: group.name, hostId: host.id,
                                                                         label: (host.names ?? []).joined(separator: ", ").nonBlank ?? "#\(host.id)"))
                                    }
                                    .labelStyle(.iconOnly)
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }
        .overlay { if groups == nil { ProgressView("Loading Proxy64…") } }
        .navigationTitle(Tabs.proxy64.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addHost() } label: { Label("New proxy host", systemImage: "plus") }
                    .disabled(groups == nil || nodes.proxyIds.isEmpty)
            }
        }
        .navigationDestination(for: ProxyHostRoute.self) { editor($0) }
        .navigationDestination(item: $newHost) { editor($0) }
        .refreshable { await load() }
        .task(id: nodes.proxyIds) { await load() }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .addDomain:
                CdnAddSheet(exclude: Set(cloudNames ?? [])) { Task { await load() } }
            case .pickNode:
                DynDNSSheet(title: "Select node") {
                    Section {
                        ForEach(nodes.proxyIds, id: \.self) { id in
                            Button(nodes.name(of: id)) {
                                self.sheet = nil
                                newHost = ProxyHostRoute(nodeId: id, hostId: nil)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
                .presentationDetents([.medium])
            case .enableCdn(let choice):
                CdnModeSheet(hostLabel: choice.label) { mode, healthcheck in
                    if let failure = await nodes.enableCdn64(choice, mode: mode, healthcheck: healthcheck) { error = failure }
                    await reload(node: choice.nodeId)
                }
            }
        }
        .errorAlert($error)
    }

    private var cdnSection: some View {
        Section("CDN64") {
            NavigationLink {
                CdnView(popToRootTab: $popToRootTab, nodeMode: true)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CDN64")
                    Text(cloudNames.map { String(localized: "\($0.count) domains") } ?? String(localized: "Cloud CDN from ipv64.net"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Button { sheet = .addDomain } label: { Label("Add domain to CDN64", systemImage: "plus.circle") }
        }
    }

    private func editor(_ route: ProxyHostRoute) -> some View {
        ProxyHostEditView(route: route) { Task { await reload(node: route.nodeId) } }
    }

    private func addHost() {
        if nodes.proxyIds.count == 1, let id = nodes.proxyIds.first {
            newHost = ProxyHostRoute(nodeId: id, hostId: nil)
        } else if nodes.proxyIds.count > 1 {
            sheet = .pickNode
        }
    }

    /// Only the changed node is loaded again.
    private func reload(node id: String) async {
        let fresh = await nodes.loadProxyNode(id, withHosts: true)
        if let index = groups?.firstIndex(where: { $0.id == id }) { groups?[index] = fresh } else { await load() }
    }

    private func load() async {
        let api = session.api
        async let me = try? ipv64Retrying { try await api.account.me() }
        async let cloud = try? ipv64Retrying { try await api.cdn.list() }
        let loaded = await nodes.loadProxyNodes(withHosts: true)
        usage = await me?.usage
        cloudNames = await cloud?.compactMap(\.domain)
        if !Task.isCancelled { groups = loaded }
    }
}

private enum ProxySheet: Identifiable {
    case addDomain, pickNode
    case enableCdn(CdnHostChoice)

    var id: String {
        switch self {
        case .addDomain: "add"
        case .pickNode: "node"
        case .enableCdn(let choice): "cdn/" + choice.id
        }
    }
}
