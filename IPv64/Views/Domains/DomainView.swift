import SwiftUI
import IPv64

/// Domain list (API v2), alphabetical, kind filter, IP status checked in the background from top to bottom.
struct DomainView: View {
    @Environment(Session.self) private var session
    @Binding var popToRootTab: Tabs
    @State private var rows: [DomainRow]?
    @State private var details: [String: DomainDetail] = [:]
    @State private var myV4 = DynDNSLogic.noIPv4
    @State private var myV6 = DynDNSLogic.noIPv6
    @State private var filter = DomainKindFilter.all
    @State private var showNewDomainSheet = false
    @State private var isDomainChanged = false
    @State private var reloadVersion = 0
    @State private var error: ErrorText?
    /// Bumped after every list load; restarts the background IP check.
    @State private var loadCount = 0

    private var visible: [DomainRow] {
        (rows ?? []).filter { filter.matches(kind: $0.kind, name: $0.name) }
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            listView.setColorGradient(showNewDomainSheet ? .clear : .orange)
        } else { listView }
    }

    private var listView: some View {
        List(visible) { row in
            NavigationLink(value: DomainRoute(name: row.name)) {
                DomainItemView(row: row, status: status(of: row))
            }
        }
        .overlay { emptyState }
        .navigationTitle(Tabs.domain.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: DomainRoute.self) { route in
            LegacyDomainDetail(name: route.name, isChanged: $isDomainChanged)
        }
        .toolbar { toolbar }
        .refreshable { await reload() }
        .task(id: reloadVersion) { await reload() }
        .task(id: loadCount) { await checkIPs() }
        .onChange(of: isDomainChanged) { _, changed in
            guard changed else { return }
            isDomainChanged = false
            details = [:]
            reloadVersion += 1
        }
        .sheet(isPresented: $showNewDomainSheet) { DomainNewView(isChanged: $isDomainChanged) }
        .errorAlert($error)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Kind", selection: $filter) {
                    ForEach(DomainKindFilter.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                Label("Filter domains", systemImage: filter == .all
                      ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
            }
        }
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showNewDomainSheet = true } label: { Label("Add domain", image: "network.badge.plus") }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if rows == nil {
            ProgressView("Loading domains…")
        } else if visible.isEmpty {
            if rows?.isEmpty == true {
                ContentUnavailableView {
                    Label("No domains yet", systemImage: "network")
                } description: {
                    Text("Add your first domain to manage its DNS records.")
                } actions: {
                    Button("Add domain") { showNewDomainSheet = true }
                }
            } else {
                ContentUnavailableView("No domains of this kind", systemImage: "network")
            }
        }
    }

    private func status(of row: DomainRow) -> DynDNSLogic.IpStatus {
        DynDNSLogic.status(details[row.name], myV4: myV4, myV6: myV6)
    }

    private func reload() async {
        let api = session.api
        async let v4 = session.myIP(.v4)
        async let v6 = session.myIP(.v6)
        do {
            rows = try await ipv64Retrying { try await api.domains.list() }
                .compactMap { domain in
                    domain.name?.nonBlank.map {
                        DomainRow(name: $0, kind: domain.kind, wildcard: domain.wildcard == true,
                                  updates: domain.updateCount ?? 0)
                    }
                }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            loadCount += 1
        } catch is CancellationError {
        } catch {
            if rows == nil { rows = [] }
            self.error = ErrorText(error)
        }
        myV4 = await v4 ?? DynDNSLogic.noIPv4
        myV6 = await v6 ?? DynDNSLogic.noIPv6
    }

    /// Records come only with the detail: fetched one domain after another in list order, at most one per second.
    private func checkIPs() async {
        let api = session.api
        for row in rows ?? [] where details[row.name] == nil {
            let started = Date()
            guard let detail = try? await ipv64Retrying({ try await api.domains.get(row.name) }) else {
                if Task.isCancelled { return }
                continue
            }
            details[row.name] = detail
            let wait = started.addingTimeInterval(1).timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if Task.isCancelled { return }
        }
    }
}

struct DomainRow: Identifiable, Hashable {
    let name: String
    let kind: DomainKind?
    let wildcard: Bool
    let updates: Int
    var id: String { name }
}

struct DomainRoute: Hashable {
    let name: String
}

/// Opens the existing detail screen, which still works on the legacy model.
// shortcut: maps the API v2 detail to the legacy `Domain`; drop when the domain detail is ported to API v2.
private struct LegacyDomainDetail: View {
    @Environment(Session.self) private var session
    let name: String
    @Binding var isChanged: Bool
    @State private var domain: Domain?
    @State private var error: ErrorText?

    var body: some View {
        Group {
            if let domain {
                DomainDetailView(domain: domain, isChanged: $isChanged)
            } else {
                ProgressView()
            }
        }
        .task { await load() }
        .errorAlert($error)
    }

    private func load() async {
        let api = session.api
        async let v4 = session.myIP(.v4)
        async let v6 = session.myIP(.v6)
        do {
            let detail = try await ipv64Retrying { try await api.domains.get(name) }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            domain = Domain(
                updates: detail.updateCount,
                wildcard: detail.wildcard == true ? 1 : 0,
                domainUpdateHash: detail.updateToken,
                records: (detail.records ?? []).map { record in
                    RecordInfos(recordId: record.id, content: record.content, ttl: record.ttl,
                                type: record.type?.rawValue, praefix: record.prefix ?? "",
                                lastUpdate: record.updatedAt.map(formatter.string(from:)), recordKey: record.token,
                                deactivated: record.state == .inactive ? 1 : 0, failoverPolicy: "0")
                },
                ipv6prefix: detail.ipv6Prefix, dualstack: "", deactivated: detail.active == false ? 1 : 0,
                fqdn: name, ipv4: await v4 ?? DynDNSLogic.noIPv4, ipv6: await v6 ?? DynDNSLogic.noIPv6)
        } catch {
            self.error = ErrorText(error)
        }
    }
}

#Preview { NavigationStack { DomainView(popToRootTab: .constant(.domain)) } }
