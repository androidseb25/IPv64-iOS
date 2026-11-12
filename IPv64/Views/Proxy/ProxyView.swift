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
    @State private var showAdd = false

    var body: some View {
        if #available(iOS 26.0, *) {
            listView.setColorGradient(showAdd ? .clear : .orange)
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
                            ProxyHostRow(host: host, cdn: group.cdn[host.id], edges: group.online?.edges ?? [])
                        }
                    }
                }
            }
        }
        .overlay { if groups == nil { ProgressView("Loading Proxy64…") } }
        .navigationTitle(Tabs.proxy64.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Reserved for the host editor (next step).
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: { Label("New proxy host", systemImage: "plus") }.disabled(true)
            }
        }
        .refreshable { await load() }
        .task(id: nodes.proxyIds) { await load() }
        .sheet(isPresented: $showAdd) {
            CdnAddSheet(exclude: Set(cloudNames ?? [])) { Task { await load() } }
        }
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
            Button { showAdd = true } label: { Label("Add domain to CDN64", systemImage: "plus.circle") }
        }
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
