import SwiftUI
import IPv64

/// DNS64 tab root: blocking, metrics and entries to the query log and local records of one connected node.
struct NodeDnsView: View {
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(\.scenePhase) private var scenePhase
    @Binding var popToRootTab: Tabs

    @State private var picked: String?
    @State private var range: DnsRange = .day
    @State private var data: DnsData?
    @State private var resumeToken = 0
    @State private var busy = false
    @State private var error: ErrorText?

    private struct LoadKey: Equatable { var id: String?; var range: DnsRange; var resume: Int }

    private var currentId: String? {
        picked.flatMap { nodes.dnsIds.contains($0) ? $0 : nil } ?? nodes.dnsIds.first
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(.orange)
        } else { content }
    }

    private var content: some View {
        Group {
            if let id = currentId {
                dashboard(id)
            } else {
                ContentUnavailableView("No connected node has DNS64 enabled.", systemImage: "server.rack")
            }
        }
        .navigationTitle(Tabs.dns64.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if nodes.dnsIds.count > 1, let id = currentId {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Node", selection: Binding(get: { id }, set: { picked = $0 })) {
                        ForEach(nodes.dnsIds, id: \.self) { Text(verbatim: nodes.name(of: $0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .showLoading($busy)
        .errorAlert($error)
        .task(id: LoadKey(id: currentId, range: range, resume: resumeToken)) { await load() }
        .onChange(of: scenePhase) { old, new in if new == .active && old != .active { resumeToken += 1 } }
    }

    private func dashboard(_ id: String) -> some View {
        let dns = nodes.client(for: id)?.dns64
        return List {
            if dns == nil {
                ContentUnavailableView("No direct connection to this node.", systemImage: "network.slash")
                    .listRowBackground(Color.clear)
            } else if let data, data.nodeId == id, let dns {
                let actions = DnsActions(busy: $busy, error: $error)
                NodeDnsBlockingSection(blocking: data.blocking, dns: dns, actions: actions,
                                       onChange: { self.data?.blocking = .success($0) },
                                       onExpired: { resumeToken += 1 })
                if case .success = data.blocking {
                    Section {
                        NavigationLink {
                            NodeDnsLogView(nodeId: id)
                        } label: { Label("Query log", systemImage: "list.bullet.rectangle") }
                        NavigationLink {
                            NodeDnsRecordsView(nodeId: id)
                        } label: { Label("Local DNS records", systemImage: "externaldrive.connected.to.line.below") }
                    }
                    Section {
                        Picker("Range", selection: $range) {
                            ForEach(DnsRange.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    NodeDnsMetricsSections(data: data, range: range, dns: dns, actions: actions,
                                           onCache: { self.data?.cache = $0 })
                }
            } else {
                HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
            }
        }
        .refreshable { await load() }
    }

    /// Loads every section; a node change clears the old data first.
    private func load() async {
        guard let id = currentId else { return }
        if data?.nodeId != id { data = nil }
        guard let dns = nodes.client(for: id)?.dns64 else { return }
        let result = await DnsData.load(nodeId: id, dns: dns, range: range.node)
        if !Task.isCancelled { data = result }
    }
}
