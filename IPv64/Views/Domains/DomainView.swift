import SwiftUI
import IPv64

/// Domain list (API v2): one section per zone, kind filter, IP status tag checked in the background.
struct DomainView: View {
    @Environment(Session.self) private var session
    @Binding var popToRootTab: Tabs
    @State private var rows: [DomainRow]?
    @State private var details: [String: DomainDetail] = [:]
    @State private var myV4 = DynDNSLogic.noIPv4
    @State private var myV6 = DynDNSLogic.noIPv6
    @State private var search = ""
    @State private var filter = DomainKindFilter.all
    @State private var showNewDomainSheet = false
    @State private var isDomainChanged = false
    @State private var reloadVersion = 0
    @State private var error: ErrorText?
    @State private var gate = DetailRequestGate()

    private var visible: [DomainRow] {
        (rows ?? []).filter {
            filter.matches(kind: $0.kind, name: $0.name)
                && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }

    private var groups: [(zone: String, rows: [DomainRow])] {
        let grouped = Dictionary(grouping: visible) { DynDNSLogic.baseDomain($0.name) }
        return DynDNSLogic.zones.compactMap { zone in grouped[zone].map { (zone, $0) } }
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            listView.setColorGradient(showNewDomainSheet ? .clear : .orange)
        } else { listView }
    }

    private var listView: some View {
        List {
            ForEach(groups, id: \.zone) { group in
                Section(group.zone) {
                    ForEach(group.rows) { row in
                        NavigationLink(value: DomainRoute(name: row.name)) {
                            DomainItemView(row: row, status: status(of: row))
                        }
                        .task { await ensureDetail(row.name) }
                    }
                }
            }
        }
        .overlay { emptyState }
        .searchable(text: $search, prompt: "Search domains")
        .navigationTitle(Tabs.domain.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: DomainRoute.self) { route in
            LegacyDomainDetail(name: route.name, isChanged: $isDomainChanged)
        }
        .toolbar { toolbar }
        .refreshable { await reload() }
        .task(id: reloadVersion) { await reload() }
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
                ContentUnavailableView.search(text: search)
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
                .sorted { $0.name < $1.name }
        } catch is CancellationError {
        } catch {
            if rows == nil { rows = [] }
            self.error = ErrorText(error)
        }
        myV4 = await v4 ?? DynDNSLogic.noIPv4
        myV6 = await v6 ?? DynDNSLogic.noIPv6
    }

    /// Records come only with the detail: loaded per row in the background, one request per second.
    private func ensureDetail(_ name: String) async {
        guard details[name] == nil else { return }
        let api = session.api
        let detail = await gate.run { () -> DomainDetail? in
            if Task.isCancelled { return nil }
            return try? await ipv64Retrying { try await api.domains.get(name) }
        }
        if let detail { details[name] = detail }
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

/// Serialises the per-row detail requests: one at a time, at most one per second.
@MainActor
final class DetailRequestGate {
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var last = Date.distantPast

    func run<T>(_ work: () async -> T) async -> T {
        if busy { await withCheckedContinuation { waiters.append($0) } }
        busy = true
        defer {
            busy = false
            if !waiters.isEmpty { waiters.removeFirst().resume() }
        }
        let wait = last.addingTimeInterval(1).timeIntervalSinceNow
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
        let result = await work()
        last = Date()
        return result
    }
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
