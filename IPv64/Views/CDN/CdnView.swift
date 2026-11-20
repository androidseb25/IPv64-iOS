import SwiftUI
import IPv64

/// CDN64: the CDN64 names of every connected proxy node. Tab root without a proxy node explains how to get one;
/// pushed from Proxy64 otherwise. "+" enables CDN64 for a proxy host.
struct CdnView: View {
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(Session.self) private var session
    @Binding var popToRootTab: Tabs
    @State private var usage: Me.Usage?
    @State private var overview: Cdn64Overview?
    @State private var domainsError: ErrorText?
    @State private var nodeData: [ProxyNodeData]?
    @State private var enableChoices: [CdnHostChoice]?
    @State private var error: ErrorText?

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(enableChoices != nil ? .clear : .orange)
        } else { content }
    }

    private var content: some View {
        List {
            ProxyUsageSection(usage: usage, quota: overview?.quota ?? nodeData?.lazy.compactMap { $0.online?.quota }.first)
            ForEach(nodeData ?? []) { data in
                CdnNodeSection(node: data) { id in Task { await reload(node: id) } }
            }
            CdnWebsiteSection(hosts: overview?.hosts?.filter { $0.mode == 3 }, error: domainsError)
            if nodes.proxyIds.isEmpty, !(overview?.hosts?.contains(where: { $0.mode == 3 }) ?? false) {
                ContentUnavailableView {
                    Label("No proxy node", systemImage: "cloud")
                } description: {
                    Text("Modes 1 and 2 run on a Node64 with the Proxy64 module. Connect one under More → Nodes.")
                }
            }
        }
        .overlay { if nodeData == nil { ProgressView("Loading CDN64…") } }
        .refreshable { await load() }
        .task(id: nodes.proxyIds) { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { enable() } label: { Label("Enable CDN64 for a proxy host", systemImage: "plus") }
                    .disabled(nodeData == nil || nodes.proxyIds.isEmpty)
            }
        }
        .sheet(isPresented: Binding(get: { enableChoices != nil }, set: { if !$0 { enableChoices = nil } })) {
            CdnEnableFlow(choices: enableChoices ?? []) { choice, mode, healthcheck in
                if let failure = await nodes.enableCdn64(choice, mode: mode, healthcheck: healthcheck) { error = failure }
                await reload(node: choice.nodeId)
            }
        }
        .errorAlert($error)
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
        let api = session.api
        async let me = try? ipv64Retrying { try await api.account.me() }
        let key = session.apiKey
        async let website: Result<Cdn64Overview, Error> = {
            do { return .success(try await Cdn64Overview.load(apiKey: key)) } catch { return .failure(error) }
        }()
        let loaded = await nodes.loadProxyNodes(withHosts: true)
        guard !Task.isCancelled else { return }
        nodeData = loaded // the node sections must not wait for the website
        let (account, list) = await (me, website)
        guard !Task.isCancelled else { return }
        usage = account?.usage
        switch list {
        case .success(let value): overview = value; domainsError = nil
        case .failure(let failure):
            if !(failure is CancellationError || (failure as? URLError)?.code == .cancelled) {
                overview = nil; domainsError = failure as? ErrorText ?? ErrorText(failure)
            }
        }
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

/// CDN64 names in Mode 3 (without Node64, set up on the website), read-only.
private struct CdnWebsiteSection: View {
    let hosts: [Cdn64Host]?
    let error: ErrorText?

    var body: some View {
        Section("Without Node64 (Mode 3)") {
            if let error {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: error.title)
                    Text(verbatim: error.message).font(.subheadline).foregroundStyle(.secondary)
                }
            } else if let hosts {
                ForEach(hosts) { row($0) }
                if hosts.isEmpty { Text("No Mode 3 names yet. Set them up on ipv64.net.").foregroundStyle(.secondary) }
            }
        }
    }

    private func row(_ host: Cdn64Host) -> some View {
        let target = host.target?.target?.nonBlank.map { "→ \($0)" + (host.target?.port.map { ":\($0)" } ?? "") }
        let bytes = { (n: Int64?) in ByteCountFormatter.string(fromByteCount: n ?? 0, countStyle: .file) }
        let traffic = host.trafficMonth.map { "↓ \(bytes($0.bytesOut))  ↑ \(bytes($0.bytesIn))" }
        let edges = (host.edges ?? []).compactMap { $0.name?.nonBlank }.joined(separator: ", ")
        let line = [target, traffic, edges.count <= 20 ? edges.nonBlank : nil].compactMap { $0 }.joined(separator: " · ")
        let problem = [host.blockedReason, host.error].lazy.compactMap { $0?.nonBlank }.first
        let tag: ProxyLogic.Tag = if host.paused == true {
            ProxyLogic.Tag(text: String(localized: "Paused"), tone: .gray)
        } else {
            switch host.status {
            case "active": ProxyLogic.Tag(text: String(localized: "Active"), tone: .green)
            case "blocked": ProxyLogic.Tag(text: String(localized: "Blocked"), tone: .red)
            default: ProxyLogic.Tag(text: String(localized: "Pending"), tone: .orange)
            }
        }
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: (host.wildcard == true ? "*." : "") + (host.fqdn?.nonBlank ?? "–")).font(.headline).lineLimit(1)
                if !line.isEmpty { Text(verbatim: line).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
                if let problem { Text(verbatim: problem).font(.footnote).foregroundStyle(.red) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ProxyTag(tag: tag)
        }
    }
}
