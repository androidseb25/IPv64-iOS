import SwiftUI
import IPv64

/// CDN64 root (spec 03 §1). Tab root without a proxy node; pushed from Proxy64 ("CDN64" row) otherwise.
struct CdnView: View {
    @Environment(Session.self) private var session
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(Router.self) private var router

    @State private var online: [NodeOnline] = []
    @State private var domains: [CDNDomain]?
    @State private var availability = ProxyLogic.Availability.unknown
    @State private var usage: Me.Usage?
    @State private var notAvailable: String?
    @State private var loaded = false
    @State private var sheet: CdnSheet?
    @State private var busy: LocalizedStringKey?
    @State private var error: ErrorText?

    private struct LoadKey: Hashable { let reload: Int; let account: Int; let nodes: [String] }
    private var loadKey: LoadKey { LoadKey(reload: router.reloadToken, account: session.accountRevision, nodes: nodes.proxyIds) }

    private var canCreate: Bool { !online.isEmpty || availability.canCreate }

    var body: some View {
        CdnList(isRoot: !nodes.proxyActive) {
            if let notAvailable, online.isEmpty {
                NotAvailableView(feature: "CDN", reason: notAvailable)
            } else {
                ProxyStatsSection(usage: usage, quota: online.lazy.compactMap { $0.status?.quota }.first)
                ForEach(online) { NodeStatusSection(node: $0) }
                if online.isEmpty, case .limitReached(let used, let limit) = availability {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Plan limit reached (\(used) of \(limit) domains)")
                            Text("Remove a domain from the CDN or upgrade your plan to add more.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                DomainsSection(domains: domains ?? [], hasNodes: !online.isEmpty, loaded: domains != nil)
            }
        }
        .navigationTitle("CDN64")
        .overlay { if !loaded { LoadingView() } }
        .refreshable { await load() }
        .task(id: loadKey) { await load() }
        .toolbar {
            if notAvailable == nil || !online.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add domain to CDN", systemImage: "plus") { Task { await add() } }
                        .opacity(canCreate ? 1 : 0.4)
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .enableFlow(let choices):
                CdnEnableFlow(choices: choices) { choice, mode, healthcheck in
                    Task { await enable(choice, mode: mode, healthcheck: healthcheck) }
                }
            case .domainPicker:
                DomainPickerSheet(exclude: Set((domains ?? []).compactMap(\.domain))) { name in
                    Task { await add(domain: name) }
                }
            }
        }
        .loadingOverlay(busy != nil, text: busy ?? "")
        .errorAlert($error) { Task { await load() } }
    }

    // MARK: Loading

    private func load() async {
        notAvailable = nil
        do {
            online = await nodes.loadNodeOnline()
            if !online.isEmpty {
                // The old cloud CDN is optional next to CDN64 (the plan may exclude it).
                if let me = try? await ipv64Retrying({ try await session.api.account.me() }) {
                    usage = me.usage
                    availability = me.cdnAvailability
                    if availability != .notInPlan {
                        domains = try? await ipv64Retrying { try await session.api.cdn.list() }
                    }
                }
            } else {
                do {
                    let me = try await ipv64Retrying { try await session.api.account.me() }
                    usage = me.usage
                    availability = me.cdnAvailability
                } catch where !isCancellation(error) {
                    availability = .unknown
                }
                if availability == .notInPlan {
                    notAvailable = String(localized: "Your plan does not include the CDN.")
                } else {
                    domains = try await ipv64Retrying { try await session.api.cdn.list() }
                }
            }
        } catch {
            if let e = error as? IPv64Error, e.isPlanRestricted {
                notAvailable = e.planRestrictionText
            } else if !isCancellation(error) {
                self.error = ErrorText(error)
            }
        }
        if !Task.isCancelled { loaded = true }
    }

    // MARK: Actions

    private func add() async {
        if !online.isEmpty {
            busy = "Loading..."
            let choices = await nodes.cdnChoices(for: online.map { ($0.id, $0.name, Set($0.status?.names?.compactMap(\.hostID) ?? [])) })
            busy = nil
            sheet = .enableFlow(choices)
        } else if !canCreate {
            error = cdnLimitError(availability)
        } else if domains == nil {
            await load()
        } else {
            sheet = .domainPicker
        }
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
}

private enum CdnSheet: Identifiable {
    case enableFlow([CdnHostChoice])
    case domainPicker

    var id: String {
        switch self {
        case .enableFlow: "enable"
        case .domainPicker: "picker"
        }
    }
}

/// Sidebar list (selection drives the detail column) when root, plain list when pushed.
private struct CdnList<Content: View>: View {
    @Environment(Router.self) private var router
    let isRoot: Bool
    @ViewBuilder let content: Content

    var body: some View {
        @Bindable var router = router
        if isRoot {
            List(selection: $router.selection) { content }
        } else {
            List { content }
        }
    }
}

// MARK: - Sections

private struct NodeStatusSection: View {
    let node: NodeOnline

    var body: some View {
        Section {
            if let status = node.status {
                let edges = status.edges ?? []
                VStack(alignment: .leading, spacing: 2) {
                    Text(edges.isEmpty ? "No CDN64 servers" : "Servers: \(edges.filter { $0.connected == true }.count) of \(edges.count) connected")
                    if let sync = status.syncError?.nonBlank { Text(verbatim: sync).font(.subheadline).foregroundStyle(.secondary) }
                }
                ForEach(Array((status.names ?? []).enumerated()), id: \.offset) { _, name in
                    if let hostID = name.hostID {
                        NavigationLink(value: Route.proxyHostEdit(nodeId: node.id, hostId: hostID)) { NameRow(name: name) }
                    } else {
                        NameRow(name: name)
                    }
                }
                if (status.names ?? []).isEmpty {
                    Text("No names in CDN64 yet. Tap + to add one.").foregroundStyle(.secondary)
                }
            } else {
                Text(verbatim: node.error ?? String(localized: "CDN64 status not available."))
            }
        } header: {
            Text(verbatim: node.name)
        }
    }
}

private struct NameRow: View {
    let name: Node64.CDNOnlineName

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name.name?.nonBlank ?? "–")
                if let check = name.check?.nonBlank {
                    Text("Check: \(check)").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            StatusChip(verbatim: ProxyLogic.cdnModeShort(name.mode), color: .ipv64Blue)
        }
    }
}

private struct DomainsSection: View {
    let domains: [CDNDomain]
    let hasNodes: Bool
    let loaded: Bool

    var body: some View {
        if !hasNodes && loaded && domains.isEmpty {
            EmptyStateView("No domains in the CDN yet. Tap + to add one.")
        } else if !domains.isEmpty {
            Section {
                ForEach(domains) { domain in
                    NavigationLink(value: Route.cdnDetail(token: domain.id)) { CdnRow(domain: domain) }
                }
            } header: {
                if hasNodes { Text("Old CDN") }
            }
        }
    }
}

private struct CdnRow: View {
    let domain: CDNDomain

    var body: some View {
        let server = domain.server?.name?.nonBlank.map { "Server \($0) · " } ?? ""
        let proxy = "Proxy: " + (domain.proxy?.state).label + (domain.portmapper?.state == .on ? " · Port mapper" : "")
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: domain.displayName)
                Text(verbatim: server + domain.trafficText + "\n" + proxy)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if domain.isBusy {
                StatusChip("Working", color: .ipv64Orange)
            } else if domain.active == true {
                StatusChip("Active", color: .ipv64Green)
            } else {
                StatusChip("Inactive", color: .ipv64Gray)
            }
        }
    }
}
