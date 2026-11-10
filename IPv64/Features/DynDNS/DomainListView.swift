import SwiftUI
import IPv64

/// DynDNS list (tab root, sidebar; spec 02 A1).
struct DomainListView: View {
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    @State private var domains: [Domain]?
    @State private var details: [String: DomainDetail] = [:]
    @State private var myV4 = DynDNSLogic.noIPv4
    @State private var myV6 = DynDNSLogic.noIPv6
    @State private var filter = DomainKindFilter.all
    @State private var error: ErrorText?
    @State private var showNew = false
    @State private var gate = DetailRequestGate()

    var body: some View {
        @Bindable var router = router
        List(selection: $router.selection) {
            Section {
                Picker("Kind", selection: $filter) {
                    ForEach(DomainKindFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            // One section per zone, as in the 2.0 app.
            ForEach(zones, id: \.self) { zone in
                Section(zone) {
                    ForEach(visible.filter { DynDNSLogic.baseDomain($0.name ?? "") == zone }, id: \.id) { domain in
                        if let name = domain.name {
                            row(domain, name: name)
                        }
                    }
                }
            }
        }
        .overlay {
            if domains == nil {
                LoadingView()
            } else if visible.isEmpty {
                emptyState
            }
        }
        .navigationTitle("DynDNS")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New domain", systemImage: "plus") { showNew = true }
            }
            .appVisibilityPriorityHigh()
        }
        .refreshable { await load(pull: true) }
        .task(id: "\(router.reloadToken)-\(session.accountRevision)") { await load(pull: false) }
        .sheet(isPresented: $showNew) {
            DomainNewSheet {
                showNew = false
                router.reload()
            }
        }
        .errorAlert($error) { Task { await load(pull: false) } }
    }

    private var zones: [String] {
        var seen: [String] = []
        for zone in visible.map({ DynDNSLogic.baseDomain($0.name ?? "") }) where !seen.contains(zone) { seen.append(zone) }
        return seen
    }

    private var visible: [Domain] {
        guard let domains else { return [] }
        return DynDNSLogic.sortedByZone(domains.filter { filter.matches(kind: $0.kind, name: $0.name ?? "") })
    }

    @ViewBuilder private var emptyState: some View {
        if domains?.isEmpty == true {
            ContentUnavailableView {
                Label("No domains yet.", systemImage: "network")
            } actions: {
                Button("New domain") { showNew = true }.buttonStyle(.bordered)
            }
        } else {
            ContentUnavailableView("No domains of this kind.", systemImage: "network")
        }
    }

    private func row(_ domain: Domain, name: String) -> some View {
        let detail = details[name]
        let status = DynDNSLogic.status(detail, myV4: myV4, myV6: myV6)
        var parts = ["Updates: \(domain.updateCount ?? 0)", "Wildcard: \(domain.wildcard == true ? "yes" : "no")"]
        if DynDNSLogic.isOwn(kind: domain.kind, name: name) { parts.append("Own domain") }
        return NavigationLink(value: Route.domainDetail(name: name)) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle().fill(status.color).frame(width: 10, height: 10).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: name).font(.headline)
                    ForEach(parts, id: \.self) { Text(verbatim: $0).font(.subheadline) }
                    Text(status.label).font(.caption).foregroundStyle(status.color)
                    if domain.active == false { Text("Inactive").font(.caption).foregroundStyle(.secondary) }
                }
            }
            .padding(.vertical, 4)
        }
        .task(id: "\(name)-\(detail != nil)") { await ensureDetail(name) }
    }

    // MARK: Loading

    private func load(pull: Bool) async {
        async let v4 = session.myIP(.v4)
        async let v6 = session.myIP(.v6)
        do {
            let list = try await ipv64Retrying { try await session.api.domains.list() }
                .filter { $0.name?.trimmingCharacters(in: .whitespaces).isEmpty == false }
            var cached: [String: DomainDetail] = [:]
            for case let name? in list.map(\.name) {
                cached[name] = DomainCache.get(name, revision: session.accountRevision)
            }
            details = cached
            domains = list
        } catch {
            if !Task.isCancelled { self.error = ErrorText(error) }
        }
        myV4 = await v4 ?? DynDNSLogic.noIPv4
        myV6 = await v6 ?? DynDNSLogic.noIPv6
    }

    private func ensureDetail(_ name: String) async {
        guard details[name] == nil else { return }
        let revision = session.accountRevision
        let api = session.api
        let result = await gate.run { () -> DomainDetail? in
            if Task.isCancelled { return nil }
            do {
                return try await api.domains.get(name)
            } catch let e as IPv64Error where e.isRateLimited {
                try? await Task.sleep(for: .seconds(e.retryAfterSeconds ?? 5))
                return try? await api.domains.get(name)
            } catch {
                return nil
            }
        }
        guard let result, revision == session.accountRevision else { return }
        DomainCache.put(result, revision: revision)
        details[name] = result
    }
}

extension DomainKindFilter {
    var title: LocalizedStringKey {
        switch self {
        case .all: "All"
        case .dyndns: "DynDNS"
        case .own: "Own"
        }
    }
}
