import SwiftUI
import IPv64

/// DNS64 tab root / DNS64 dashboard of a node (spec 03 §6).
struct NodeDnsView: View {
    /// `nil` = DNS64 tab root (node picker); else the dashboard of that node.
    var nodeId: String? = nil

    @Environment(ConnectedNodes.self) private var nodes
    @Environment(\.scenePhase) private var scenePhase

    @State private var picked: String?
    @State private var range: DnsRange = .day
    @State private var data: DnsData?
    @State private var dns: Node64.DNS64?
    @State private var noConfig = false
    @State private var resumeToken = 0
    @State private var busy: LocalizedStringKey?
    @State private var error: ErrorText?

    private struct LoadKey: Equatable { var id: String?; var range: DnsRange; var resume: Int }

    private var currentId: String? {
        nodeId ?? picked.flatMap { nodes.dnsIds.contains($0) ? $0 : nil } ?? nodes.dnsIds.first
    }

    private var title: String {
        guard let nodeId else { return "DNS64" }
        return LocalNodeStore.name(nodeId)?.nonBlank ?? String(localized: "Local DNS")
    }

    var body: some View {
        Group {
            if let id = currentId {
                dashboard(id)
            } else {
                ContentUnavailableView("No connected node has DNS64 enabled.", systemImage: "server.rack")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(nodeId == nil ? .large : .inline)
        .loadingOverlay(busy != nil, text: busy ?? "Updating...")
        .errorAlert($error)
        .task(id: LoadKey(id: currentId, range: range, resume: resumeToken)) { await load() }
        .onChange(of: scenePhase) { old, new in if new == .active && old != .active { resumeToken += 1 } }
    }

    private func dashboard(_ id: String) -> some View {
        List {
            if nodeId == nil && nodes.dnsIds.count > 1 {
                Section {
                    Picker("Node", selection: Binding(get: { id }, set: { picked = $0 })) {
                        ForEach(nodes.dnsIds, id: \.self) { Text(verbatim: nodes.name(of: $0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
            if noConfig {
                ContentUnavailableView("No direct connection to this node.", systemImage: "network.slash")
                    .listRowBackground(Color.clear)
            } else if let data, data.nodeId == id, let dns {
                let actions = DnsActions(busy: $busy, error: $error)
                NodeDnsBlockingSection(blocking: data.blocking, dns: dns, actions: actions,
                                       onChange: { self.data?.blocking = .success($0) },
                                       onExpired: { resumeToken += 1 })
                if case .success = data.blocking {
                    Section {
                        NavigationLink(value: Route.nodeDnsLog(nodeId: id)) {
                            LabeledContent { Text("Live") } label: { Label("Query log", systemImage: "list.bullet.rectangle") }
                        }
                        NavigationLink(value: Route.nodeDnsRecords(nodeId: id)) {
                            Label("Local DNS records", systemImage: "externaldrive.connected.to.line.below")
                        }
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
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
                    .listRowBackground(Color.clear)
            }
        }
        .refreshable { await load() }
    }

    /// Re-reads the stored access and loads every section; a node change clears the old data first.
    private func load() async {
        guard let id = currentId else { return }
        if data?.nodeId != id { data = nil }
        guard let client = nodes.client(for: id) else {
            dns = nil
            noConfig = true
            return
        }
        noConfig = false
        dns = client.dns64
        let result = await DnsData.load(nodeId: id, dns: client.dns64, range: range.node)
        if !Task.isCancelled { data = result }
    }
}
