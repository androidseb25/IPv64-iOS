import SwiftUI
import IPv64

/// CDN64 tab (API v2, the account's CDN domains): usage section, compact rows, add and delete.
struct CdnView: View {
    @Environment(Session.self) private var session
    @Binding var popToRootTab: Tabs
    @State private var domains: [CDNDomain]?
    @State private var usage: Me.Usage?
    @State private var showAdd = false
    @State private var confirmDelete: CDNDomain?
    @State private var deletedIDs: Set<String> = []
    @State private var error: ErrorText?

    private var availability: CdnLogic.Availability {
        CdnLogic.availability(used: usage?.cdnDomains?.used, limit: usage?.cdnDomains?.limit)
    }

    private var visible: [CDNDomain] {
        (domains ?? []).filter { !deletedIDs.contains($0.id) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private var isBusy: Bool { visible.contains { $0.isBusy } }

    var body: some View {
        if #available(iOS 26.0, *) {
            listView.setColorGradient(showAdd ? .clear : .orange)
        } else { listView }
    }

    private var listView: some View {
        List {
            if availability != .notInPlan {
                CdnUsageSection(usage: usage)
                if case .limitReached(let used, let limit) = availability {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Plan limit reached (\(used) of \(limit) domains)")
                            Text("Remove a domain from the CDN or upgrade your plan to add more.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                ForEach(visible) { domain in
                    CdnItemView(domain: domain)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = domain }
                                .labelStyle(.iconOnly)
                                .tint(.red)
                        }
                }
            }
        }
        .overlay { emptyState }
        .navigationTitle(Tabs.cdn.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .refreshable { await load() }
        .task { await load() }
        // Polls while the CDN bot works (AGENTS.md rule 8); ends with the view or when nothing is pending.
        .task(id: isBusy) {
            while isBusy && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                if Task.isCancelled { return }
                await load(silent: true)
            }
        }
        .sheet(isPresented: $showAdd) {
            CdnAddSheet(exclude: Set((domains ?? []).compactMap(\.domain))) { Task { await load() } }
        }
        .alert("Remove from CDN?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
               presenting: confirmDelete) { domain in
            Button("Remove", role: .destructive) { Task { await delete(domain) } }
            Button("Cancel", role: .cancel) {}
        } message: { domain in
            Text("Do you really want to remove \"\(domain.displayName)\" from the CDN? Turn the CDN off for all its records first.")
        }
        .errorAlert($error)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if availability != .notInPlan {
            ToolbarItem(placement: .topBarTrailing) {
                Button { add() } label: { Label("Add domain to CDN", systemImage: "plus") }
                    .disabled(domains == nil)
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if domains == nil {
            ProgressView("Loading CDN…")
        } else if availability == .notInPlan {
            ContentUnavailableView("CDN not available", systemImage: "cloud",
                                   description: Text("Your plan does not include the CDN."))
        } else if visible.isEmpty {
            ContentUnavailableView {
                Label("No domains in the CDN yet", systemImage: "cloud")
            } description: {
                Text("Add a domain to serve it through the CDN.")
            } actions: {
                Button("Add domain") { add() }
            }
        }
    }

    private func add() {
        if case .limitReached(_, let limit) = availability {
            error = ErrorText(title: String(localized: "Plan limit reached"),
                              message: String(localized: "Your plan allows \(limit) CDN domains. Remove one or upgrade your plan."))
        } else {
            showAdd = true
        }
    }

    private func load(silent: Bool = false) async {
        let api = session.api
        do {
            async let me = ipv64Retrying { try await api.account.me() }
            let list = try await ipv64Retrying { try await api.cdn.list() }
            domains = list
            usage = try? await me.usage
            deletedIDs.formIntersection(list.map(\.id))
        } catch is CancellationError {
        } catch {
            if domains == nil { domains = [] }
            if !silent { self.error = ErrorText(error) }
        }
    }

    private func delete(_ domain: CDNDomain) async {
        let api = session.api
        _ = withAnimation { deletedIDs.insert(domain.id) }
        do {
            _ = try await ipv64Retrying { try await api.cdn.delete(domain.id) }
            await load()
        } catch {
            _ = withAnimation { deletedIDs.remove(domain.id) }
            self.error = ErrorText(error)
        }
    }
}

extension CDNDomain {
    var isBusy: Bool { CdnLogic.isBusy(pending: pending, proxy: proxy?.state, portmapper: portmapper?.state) }
    var displayName: String { CdnLogic.displayName(domain: domain, id: id) }
}

#Preview { NavigationStack { CdnView(popToRootTab: .constant(.cdn)) } }
