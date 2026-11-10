import SwiftUI
import IPv64

/// Domain detail (spec 02 A3).
struct DomainDetailView: View {
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    let name: String

    @State private var detail: DomainDetail?
    @State private var myV4 = DynDNSLogic.noIPv4
    @State private var myV6 = DynDNSLogic.noIPv6
    @State private var busy: LocalizedStringKey?
    @State private var error: ErrorText?
    @State private var confirm: ConfirmRequest?
    @State private var sheet: DetailSheet?
    @State private var copied = 0

    enum DetailSheet: Identifiable {
        case newRecord, dynDns, rotated(String)
        var id: String {
            switch self {
            case .newRecord: "record"
            case .dynDns: "dyndns"
            case .rotated: "rotated"
            }
        }
    }

    private var mismatchV4: Bool { DynDNSLogic.mismatchV4(detail, myV4: myV4) }
    private var mismatchV6: Bool { DynDNSLogic.mismatchV6(detail, myV6: myV6) }
    private var updateURL: String? { DynDNSLogic.updateURL(token: detail?.updateToken) }

    var body: some View {
        Group {
            if detail == nil && error == nil {
                LoadingView()
            } else if let detail {
                content(detail)
            } else {
                Color.clear
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New DNS record", systemImage: "plus") { sheet = .newRecord }.disabled(detail == nil)
            }
            .appVisibilityPriorityHigh()
            AppMoreMenu("More actions", disabled: detail == nil) {
                Button("Rotate update token", systemImage: "key") { askRotate() }
                Divider()
                Button("Reset domain", systemImage: "arrow.counterclockwise", role: .destructive) { askReset() }
                Button("Delete domain", systemImage: "trash", role: .destructive) { askDelete() }
            }
        }
        .task(id: "\(router.reloadToken)-\(session.accountRevision)") { await load() }
        .loadingOverlay(busy != nil, text: busy ?? "Loading...")
        .errorAlert($error) { Task { await load() } }
        .confirmDialog($confirm)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .newRecord:
                RecordNewSheet(domain: name) { self.sheet = nil; router.reload() }
            case .dynDns:
                DomainDynDnsSheet(domain: name) { router.reload() }
            case .rotated(let url):
                RotatedTokenSheet(url: url)
            }
        }
        .sensoryFeedback(.success, trigger: copied)
        .task(id: copied) {
            guard copied > 0 else { return }
            try? await Task.sleep(for: .seconds(1.5))
            copyFlash = false
        }
    }

    private func content(_ detail: DomainDetail) -> some View {
        List {
            if mismatchV4 || mismatchV6 {
                Section {
                    Text("Your A or AAAA record doesn't match your current IP! This could be due to an active cellular connection or the IP address being assigned a server address.")
                    Button(mismatchV4 && mismatchV6 ? "Set A and AAAA records to current IP?"
                           : mismatchV4 ? "Set A-Record to current IP?" : "Set AAAA-Record to current IP?") {
                        Task { await setToCurrentIP() }
                    }
                }
                .listRowBackground(Color.ipv64Orange.opacity(0.2))
            }
            Section {
                LabeledContent {
                    if detail.active == false {
                        StatusChip("Inactive", color: .ipv64Gray)
                    } else {
                        let status = DynDNSLogic.status(detail, myV4: myV4, myV6: myV6)
                        StatusChip(status.label, color: status.color)
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(verbatim: name)
                        Text(verbatim: DynDNSLogic.kindLabel(detail.kind)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Wildcard", value: detail.wildcard == true ? "yes" : "no")
                LabeledContent("Updates", value: "\(detail.updateCount ?? 0)")
                LabeledContent("Ignored on DynDNS updates", value: DynDNSLogic.ignoreLabel(detail.ignore))
                LabeledContent("Fixed IPv6 prefix") {
                    if let prefix = detail.ipv6Prefix?.nonBlank {
                        Text(verbatim: prefix).font(.body.monospaced())
                    } else {
                        Text("Off")
                    }
                }
                if let created = detail.createdAt {
                    LabeledContent("Created", value: Formatters.germanTime(created))
                }
            }
            Section {
                ActionTileRow {
                    ActionTile(copyFlash ? "Copied" : "Copy update URL", systemImage: copyFlash ? "checkmark" : "doc.on.doc") {
                        guard let updateURL else { return }
                        Clipboard.copy(updateURL, sensitive: true)
                        copied += 1
                        copyFlash = true
                    }
                    .disabled(updateURL == nil)
                    ActionTile("DynDNS update", systemImage: "arrow.triangle.2.circlepath") { sheet = .dynDns }
                    ActionTile("Settings", systemImage: "slider.horizontal.3") {
                        router.push(.domainSettings(name: name))
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            records(detail)
        }
        .refreshable { await refresh() }
    }

    @State private var copyFlash = false

    @ViewBuilder private func records(_ detail: DomainDetail) -> some View {
        let groups = DynDNSLogic.groupedRecords(detail.records ?? [])
        if groups.isEmpty {
            Section { Text("No DNS records.").foregroundStyle(.secondary) }
        }
        ForEach(groups, id: \.type) { group in
            Section("\(group.type) records (\(group.records.count))") {
                ForEach(group.records) { record in
                    RecordRow(record: record) {
                        router.push(.recordEdit(domain: name, recordId: String(record.id)))
                    } onDelete: {
                        askDelete(record)
                    }
                }
            }
        }
    }

    // MARK: Loading

    private func load() async {
        if let cached = DomainCache.get(name, revision: session.accountRevision) { detail = cached }
        async let v4 = session.myIP(.v4)
        async let v6 = session.myIP(.v6)
        await fetch()
        myV4 = await v4 ?? DynDNSLogic.noIPv4
        myV6 = await v6 ?? DynDNSLogic.noIPv6
    }

    private func refresh() async { await load() }

    private func fetch() async {
        do {
            let fresh = try await ipv64Retrying { try await session.api.domains.get(name) }
            DomainCache.put(fresh, revision: session.accountRevision)
            detail = fresh
        } catch {
            if !Task.isCancelled { self.error = ErrorText(error) }
        }
    }

    /// Runs a mutation behind a blocking spinner; `onError` may handle an error and return `true`.
    private func run(_ text: LocalizedStringKey, context: ErrorContext = .other,
                     onError: ((IPv64Error) -> Bool)? = nil, _ work: () async throws -> Void) async {
        busy = text
        defer { busy = nil }
        do {
            try await work()
        } catch {
            if Task.isCancelled { return }
            if let e = error as? IPv64Error, onError?(e) == true { return }
            self.error = ErrorText(error, context: context)
        }
    }

    // MARK: Actions

    private func setToCurrentIP() async {
        let v4 = mismatchV4 ? DynDNSLogic.knownIp(myV4) : nil
        let v6 = mismatchV6 ? DynDNSLogic.knownIp(myV6) : nil
        await run("Loading...", context: .update) {
            let result = try await session.api.domains.updateDynDNS(name, ipv4: v4, ipv6: v6)
            DomainCache.invalidate(name)
            let failed = (result.results ?? []).filter { DynDNSLogic.isFailure($0.result) }
            if failed.isEmpty {
                router.pop()
                router.reload()
            } else {
                error = ErrorText(title: String(localized: "Update error"), message: failed.map {
                    "\($0.type?.rawValue ?? "") \($0.ip ?? ""): \(DynDNSLogic.outcomeLabel($0.result))"
                }.joined(separator: "\n"))
            }
        }
    }

    private func askRotate() {
        confirm = ConfirmRequest(
            title: String(localized: "Rotate update token?"),
            message: String(localized: "A new update token is created and the old one stops working immediately. Routers and scripts using the old update URL stop updating until you enter the new URL."),
            confirmLabel: String(localized: "Rotate"), destructive: true
        ) { Task { await rotate() } }
    }

    private func rotate() async {
        await run("Rotating token...") {
            let rotated = try await session.api.domains.rotateToken(name)
            if let url = DynDNSLogic.updateURL(token: rotated.updateToken) {
                DomainCache.invalidate(name)
                sheet = .rotated(url)
                await fetch()
            } else {
                DomainCache.invalidate(name)
                await fetch()
                error = ErrorText(title: String(localized: "Token rotated"),
                                  message: String(localized: "The update token was rotated. Copy the new update URL from the domain details."))
            }
        }
    }

    private func askReset() {
        confirm = ConfirmRequest(
            title: String(localized: "Reset domain?"),
            message: String(localized: "All active DNS records of \(name) are deleted and the zone is set up anew. This cannot be undone."),
            confirmLabel: String(localized: "Reset"), destructive: true, requireTyping: name
        ) { Task { await reset() } }
    }

    private func reset() async {
        await run("Resetting...") {
            let result = try await ipv64Retrying { try await session.api.domains.reset(name) }
            DomainCache.put(result, revision: session.accountRevision)
            detail = result
            router.reload()
        }
    }

    private func askDelete() {
        confirm = ConfirmRequest(
            title: String(localized: "Delete domain?"),
            message: String(localized: "Do you really want to delete \(name) with all its DNS records?"),
            confirmLabel: String(localized: "Delete"), destructive: true, requireTyping: name
        ) { Task { await deleteDomain() } }
    }

    private func deleteDomain() async {
        await run("Deleting...", onError: { e in
            guard e.isConflict else { return false }
            let text = (e.apiDetail?.nonBlank) ?? String(localized: "DNS failover is active for this domain. Remove or pause the failover policy first.")
            error = ErrorText(title: String(localized: "Domain cannot be deleted"), message: text)
            return true
        }) {
            try await session.api.domains.delete(name)
            DomainCache.invalidate(name)
            router.pop()
            router.reload()
        }
    }

    private func askDelete(_ record: Record) {
        let type = record.type?.rawValue ?? "?"
        let prefix = DynDNSLogic.prefixLabel(record.prefix)
        confirm = ConfirmRequest(
            title: String(localized: "Delete DNS record?"),
            message: String(localized: "Do you really want to delete the \(type) record \"\(prefix)\" (\(record.content ?? "–"))?"),
            confirmLabel: String(localized: "Delete"), destructive: true
        ) { Task { await deleteRecord(record) } }
    }

    private func deleteRecord(_ record: Record) async {
        await run("Deleting...") {
            try await session.api.records.delete(String(record.id))
            DomainCache.invalidate(name)
            await fetch()
        }
    }
}

extension IPv64Error {
    /// Server `detail` of an API error.
    var apiDetail: String? { if case .api(let p) = self { p.detail } else { nil } }
}
