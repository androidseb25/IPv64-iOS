import SwiftUI
import IPv64

/// Proxy64 root (spec 03 §3): stats, cloud CDN64 entry, proxy hosts per connected node.
struct ProxyView: View {
    @Environment(Session.self) private var session
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(Router.self) private var router

    @State private var groups: [NodeHosts]?
    @State private var usage: Me.Usage?
    @State private var sheet: ProxySheet?
    @State private var pickNode = false
    @State private var busy: LocalizedStringKey?
    @State private var error: ErrorText?

    private struct LoadKey: Hashable { let reload: Int; let account: Int; let nodes: [String] }
    private var loadKey: LoadKey { LoadKey(reload: router.reloadToken, account: session.accountRevision, nodes: nodes.proxyIds) }

    var body: some View {
        @Bindable var router = router
        List(selection: $router.selection) {
            ProxyStatsSection(usage: usage, quota: groups?.lazy.compactMap { $0.online?.quota }.first)
            Section("CDN64") {
                NavigationLink(value: Route.cdn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CDN64")
                        Text("Cloud CDN from ipv64.net").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Button("Add domain to CDN64", action: startAddCdn)
            }
            ForEach(groups ?? []) { group in
                NodeSection(group: group)
            }
        }
        .navigationTitle("Proxy64")
        .overlay { if groups == nil { LoadingView() } }
        .refreshable { await load() }
        .task(id: loadKey) { await load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New proxy host", systemImage: "plus", action: newHost)
            }
        }
        .confirmationDialog("Select node", isPresented: $pickNode, titleVisibility: .visible) {
            ForEach(nodes.proxyIds, id: \.self) { id in
                Button(nodes.name(of: id)) { router.push(.proxyHostEdit(nodeId: id, hostId: nil)) }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .enableFlow(let choices):
                CdnEnableFlow(choices: choices) { choice, mode, healthcheck in
                    Task { await enable(choice, mode: mode, healthcheck: healthcheck) }
                }
            case .domainPicker(let exclude):
                DomainPickerSheet(exclude: exclude) { name in Task { await add(domain: name) } }
            }
        }
        .loadingOverlay(busy != nil, text: busy ?? "")
        .errorAlert($error)
    }

    // MARK: Actions

    private func newHost() {
        if nodes.proxyIds.count == 1, let id = nodes.proxyIds.first {
            router.push(.proxyHostEdit(nodeId: id, hostId: nil))
        } else if nodes.proxyIds.count > 1 {
            pickNode = true
        }
    }

    private func startAddCdn() {
        let reachable = (groups ?? []).filter { $0.error == nil }
        if !reachable.isEmpty {
            sheet = .enableFlow(reachable.flatMap(\.choices))
            return
        }
        Task { await startCloudAdd() }
    }

    /// No node reachable: plan check, then the cloud domain picker.
    private func startCloudAdd() async {
        busy = "Loading..."
        defer { busy = nil }
        do {
            let availability = (try? await ipv64Retrying { try await session.api.account.me() })?.cdnAvailability ?? .unknown
            if availability == .notInPlan {
                error = ErrorText(title: String(localized: "Not available"), message: String(localized: "Your plan does not include the CDN."))
            } else if !availability.canCreate {
                error = cdnLimitError(availability)
            } else {
                let list = try await ipv64Retrying { try await session.api.cdn.list() }
                sheet = .domainPicker(exclude: Set(list.compactMap(\.domain)))
            }
        } catch where !isCancellation(error) {
            self.error = ErrorText(error)
        } catch {}
    }

    private func add(domain: String) async {
        busy = "Adding domain..."
        defer { busy = nil }
        do {
            let created = try await ipv64Retrying { try await session.api.cdn.add(domain: domain) }
            router.push(.cdnDetail(token: created.id))
        } catch {
            self.error = cdnAddFailure(error)
        }
    }

    private func enable(_ choice: CdnHostChoice, mode: Int, healthcheck: Bool) async {
        guard let client = nodes.client(for: choice.nodeId) else { return }
        busy = "Enabling CDN64..."
        defer { busy = nil }
        do {
            if let text = try await client.enableCdn64(host: choice.hostId, mode: mode, healthcheck: healthcheck) {
                error = ErrorText(title: "CDN64", message: text)
            }
            await load()
        } catch {
            self.error = ErrorText.node(error)
        }
    }

    private func load() async {
        usage = (try? await ipv64Retrying { try await session.api.account.me() })?.usage
        let clients = nodes.proxyIds.map { ($0, nodes.name(of: $0), nodes.client(for: $0)) }
        let loaded = await NodeHosts.load(clients)
        if !Task.isCancelled { groups = loaded }
    }
}

private enum ProxySheet: Identifiable {
    case enableFlow([CdnHostChoice])
    case domainPicker(exclude: Set<String>)

    var id: String {
        switch self {
        case .enableFlow: "enable"
        case .domainPicker: "picker"
        }
    }
}

/// Hosts of one node or its error text (Android `NodeHosts`).
struct NodeHosts: Identifiable {
    let id: String
    let name: String
    let hosts: [Node64.ProxyHost]
    let error: String?
    /// CDN64 status; optional (module without tunnel/account answers with an error).
    let online: Node64.CDNOnlineStatus?

    var cdn: [Int: Node64.CDNOnlineName] { NodeOnline(id: id, name: name, status: online, error: nil).cdn }

    var choices: [CdnHostChoice] {
        hosts.filter { cdn[$0.id] == nil }.map {
            CdnHostChoice(nodeId: id, nodeName: name, hostId: $0.id,
                          label: ($0.names ?? []).joined(separator: ", ").nonBlank ?? "#\($0.id)")
        }
    }

    static func load(_ clients: [(String, String, Node64?)]) async -> [NodeHosts] {
        await withTaskGroup(of: (Int, NodeHosts).self) { group in
            for (index, entry) in clients.enumerated() {
                group.addTask {
                    let (id, name, client) = entry
                    guard let client else {
                        return (index, NodeHosts(id: id, name: name, hosts: [], error: "No access saved for this node.", online: nil))
                    }
                    do {
                        let hosts = try await client.proxy64.hosts.list()
                        let online = try? await client.proxy64.online.status()
                        return (index, NodeHosts(id: id, name: name, hosts: hosts, error: nil, online: online))
                    } catch {
                        return (index, NodeHosts(id: id, name: name, hosts: [], error: ErrorText.node(error).titledText, online: nil))
                    }
                }
            }
            var result: [(Int, NodeHosts)] = []
            for await item in group { result.append(item) }
            return result.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}

private struct NodeSection: View {
    let group: NodeHosts

    var body: some View {
        Section {
            if let error = group.error {
                Text(verbatim: error)
                Text("Check the connection under More → Nodes.").font(.footnote).foregroundStyle(.secondary)
            } else if group.hosts.isEmpty {
                Text("No hosts.").foregroundStyle(.secondary)
            }
            ForEach(group.hosts) { host in
                NavigationLink(value: Route.proxyHostEdit(nodeId: group.id, hostId: host.id)) {
                    ProxyHostRow(host: host, cdn: group.cdn[host.id], edges: group.online?.edges ?? [])
                }
            }
        } header: {
            Text(verbatim: group.name)
        }
    }
}
