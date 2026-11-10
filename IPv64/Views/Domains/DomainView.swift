import SwiftUI

struct DomainView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @Binding var popToRootTab: Tabs
    @StateObject private var api = ApiService()
    @State private var domains: [Domain] = []
    @State private var groups: [(name: String, domains: [Domain])] = []
    @State private var search = ""
    @State private var filter = DomainFilter.all
    @State private var showNewDomainSheet = false
    @State private var isDomainChanged = false
    @State private var reloadVersion = 0
    @State private var loadedAt: Date?
    @State private var loadID: UUID?
    private var isRefreshing: Bool { loadID != nil }

    private enum DomainFilter: String, CaseIterable {
        case all = "All", matching = "IP matches", different = "IP differs"
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            listView.setColorGradient(showNewDomainSheet ? .clear : .orange)
        } else { listView }
    }

    private var listView: some View {
        List {
            ForEach(groups, id: \.name) { group in
                Section(group.name) {
                    ForEach(group.domains, id: \.fqdn) { domain in
                        NavigationLink(value: domain) { DomainItemView(domain: domain) }
                    }
                }
            }
        }
        .overlay {
            if groups.isEmpty && !isRefreshing {
                if !search.isEmpty || filter != .all {
                    ContentUnavailableView.search(text: search)
                } else if loadedAt != nil {
                    ContentUnavailableView {
                        Label("No domains yet", systemImage: "network")
                    } description: {
                        Text("Add your first domain to manage its DNS records.")
                    } actions: {
                        Button("Add domain") { showNewDomainSheet = true }
                    }
                } else {
                    ContentUnavailableView {
                        Label("Domains unavailable", systemImage: "network")
                    } description: {
                        Text("Connect to the internet and try again.")
                    } actions: {
                        Button("Retry") { reloadVersion += 1 }
                    }
                }
            }
        }
        .overlay { if isRefreshing && domains.isEmpty { ProgressView("Loading domains…") } }
        .apiErrors(api)
        .searchable(text: $search, prompt: "Search domains")
        .onChange(of: search) { _, _ in updateGroups() }
        .onChange(of: filter) { _, _ in updateGroups() }
        .navigationTitle(Tabs.domain.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Domain.self) { domain in
            DomainDetailView(domain: domain, isChanged: $isDomainChanged)
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("IP status", selection: $filter) {
                        ForEach(DomainFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: { Label("Filter domains", systemImage: "line.3.horizontal.decrease") }
                .tint(systemColorScheme == .dark ? .white : .black)
            }
            ToolbarItem {
                Button { showNewDomainSheet = true } label: { Label("Add domain", image: "network.badge.plus") }
                    .tint(systemColorScheme == .dark ? .white : .black)
            }
        }
        .refreshable { await reload() }
        .task(id: reloadVersion) {
            if loadedAt == nil || isDomainChanged || loadedAt!.timeIntervalSinceNow < -30 {
                await reload()
            }
        }
        .onChange(of: isDomainChanged) { _, changed in
            if changed { loadedAt = nil; reloadVersion += 1 }
        }
        .sheet(isPresented: $showNewDomainSheet) { DomainNewView(isChanged: $isDomainChanged) }
    }

    private func reload() async {
        let requestID = UUID()
        loadID = requestID
        defer { if loadID == requestID { loadID = nil } }
        // These requests are independent: the slowest determines latency, not their sum.
        async let domainRequest = api.GetDomains()
        async let ipv4Request = api.GetMyIp()
        async let ipv6Request = api.GetMyIp(false)
        let (result, ipv4, ipv6) = await (domainRequest, ipv4Request, ipv6Request)
        guard !Task.isCancelled, loadID == requestID, let result else { return }
        domains = result.subdomains.map {
            var domain = $0
            domain.ipv4 = ipv4?.ip ?? "0.0.0.0"
            domain.ipv6 = ipv6?.ip ?? "::"
            return domain
        }.sorted(by: \.fqdn)
        loadedAt = .now
        isDomainChanged = false
        updateGroups()
    }

    private func updateGroups() {
        let visible = domains.filter { domain in
            let matches = search.isEmpty || domain.fqdn.localizedCaseInsensitiveContains(search)
            let differs = (domain.ipv4 != "0.0.0.0" && !domain.isSameTypeAAddress)
                || (domain.ipv6 != "::" && !domain.isSameTypeAAAAAddress)
            return matches && (filter == .all || (filter == .different ? differs : !differs))
        }
        let grouped = Dictionary(grouping: visible, by: \.baseDomain)
        groups = "".v64domains().compactMap { name in
            grouped[name].map { (name: name, domains: $0) }
        }
    }
}

#Preview { NavigationStack { DomainView(popToRootTab: .constant(.domain)) } }
