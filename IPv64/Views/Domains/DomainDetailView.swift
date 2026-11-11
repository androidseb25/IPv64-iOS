import SwiftUI
import IPv64

/// Domain detail (API v2): notice on IP mismatch, general info, actions, records grouped by type.
struct DomainDetailView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    let name: String
    /// Tells the list that this domain changed (it then re-checks only this domain).
    let onChanged: () -> Void

    @State private var detail: DomainDetail?
    @State private var myV4 = DynDNSLogic.noIPv4
    @State private var myV6 = DynDNSLogic.noIPv6
    @State private var reloadToken = 0
    @State private var busy = false
    @State private var isLoading = false
    @State private var error: ErrorText?
    @State private var sheet: DetailSheet?
    @State private var push: DetailPush?
    @State private var confirm: DetailConfirm?
    @State private var typedName = ""
    @State private var copied = 0
    /// Records removed from the list right away while their delete request runs (no spinner, like Mail).
    @State private var deletedRecordIds: Set<Int> = []

    enum DetailSheet: Identifiable {
        case newRecord, dynDns, settings, rotated(String)
        var id: String {
            switch self {
            case .newRecord: "record"
            case .dynDns: "dyndns"
            case .settings: "settings"
            case .rotated: "rotated"
            }
        }
    }

    enum DetailPush: Hashable {
        case record(String)
    }

    enum DetailConfirm: Identifiable {
        case setIP, rotate, reset, delete, deleteRecord(Record)
        var id: String {
            switch self {
            case .setIP: "ip"
            case .rotate: "rotate"
            case .reset: "reset"
            case .delete: "delete"
            case .deleteRecord(let record): "record-\(record.id)"
            }
        }
    }

    private var mismatchV4: Bool { DynDNSLogic.mismatchV4(detail, myV4: myV4) }
    private var mismatchV6: Bool { DynDNSLogic.mismatchV6(detail, myV6: myV6) }
    private var updateURL: String? { DynDNSLogic.updateURL(token: detail?.updateToken) }

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(sheet != nil ? .clear : .orange)
        } else {
            content
        }
    }

    private var content: some View {
        List {
            if let detail {
                notice
                general(detail)
                actions
                records(detail)
            }
        }
        .overlay {
            if detail == nil && error == nil { ProgressView() }
        }
        // While loading or running an action everything is locked; the spinner sits in the toolbar.
        .disabled(busy || isLoading)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .refreshable { await load() }
        .task(id: reloadToken) { await load() }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .newRecord: RecordNewSheet(domain: name) { changed() }
            case .dynDns: DomainDynDnsSheet(domain: name) { changed() }
            case .settings: NavigationStack { DomainSettingsView(name: name) { changed() } }
            case .rotated(let url): RotatedTokenSheet(url: url)
            }
        }
        .navigationDestination(item: $push) { target in
            switch target {
            case .record(let id): RecordEditView(recordId: id) { changed() }
            }
        }
        .alert(confirmTitle, isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
               presenting: confirm, actions: confirmActions, message: { Text(confirmMessage($0)) })
        .sensoryFeedback(.success, trigger: copied)
        .errorAlert($error)
    }

    // MARK: Sections

    /// Same as before: shown when an A or AAAA record differs from this device's IP.
    @ViewBuilder private var notice: some View {
        if mismatchV4 || mismatchV6 {
            Section("Notice") {
                Text("Your A or AAAA record doesn't match your current IP! This could be due to an active cellular connection or the IP address being assigned a server address.")
                Button(mismatchV4 && mismatchV6 ? "Set A and AAAA records to current IP?"
                       : mismatchV4 ? "Set A-Record to current IP?" : "Set AAAA-Record to current IP?") {
                    confirm = .setIP
                }
                .tint(.orange)
            }
        }
    }

    private func general(_ detail: DomainDetail) -> some View {
        Section("General") {
            LabeledContent("Status") {
                if detail.active == false {
                    Text("Inactive").foregroundStyle(.secondary)
                } else {
                    let status = DynDNSLogic.status(detail, myV4: myV4, myV6: myV6)
                    Text(status.label).foregroundStyle(status.color)
                }
            }
            LabeledContent("Type", value: DynDNSLogic.kindLabel(detail.kind))
            LabeledContent("Wildcard", value: detail.wildcard == true ? "yes" : "no")
            LabeledContent("Updates", value: "\(detail.updateCount ?? 0)")
            LabeledContent("Ignored on DynDNS updates", value: DynDNSLogic.ignoreLabel(detail.ignore))
            LabeledContent("Fixed IPv6 prefix", value: detail.ipv6Prefix?.nonBlank ?? String(localized: "Off"))
            if let created = detail.createdAt {
                LabeledContent("Created", value: DynDNSLogic.germanTime(created))
            }
        }
    }

    private var actions: some View {
        Section {
            Button {
                copyUpdateURL()
            } label: {
                Label("Copy update URL", systemImage: "doc.on.doc")
            }
            .disabled(updateURL == nil)
            Button {
                sheet = .dynDns
            } label: {
                Label("DynDNS update", systemImage: "arrow.triangle.2.circlepath")
            }
            Button {
                sheet = .settings
            } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
            }
        }
        .tint(.primary)
    }

    @ViewBuilder private func records(_ detail: DomainDetail) -> some View {
        let groups = DynDNSLogic.groupedRecords((detail.records ?? []).filter { !deletedRecordIds.contains($0.id) })
        if groups.isEmpty {
            Section { Text("No DNS records.").foregroundStyle(.secondary) }
        }
        ForEach(groups, id: \.type) { group in
            Section("\(group.type) records (\(group.records.count))") {
                ForEach(group.records) { record in
                    DomainRecordRow(record: record) {
                        push = .record(String(record.id))
                    } onDelete: {
                        confirm = .deleteRecord(record)
                    }
                }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { sheet = .newRecord } label: { Label("New DNS record", systemImage: "plus") }
                .disabled(detail == nil || busy || isLoading)
        }
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if busy || isLoading {
                ProgressView()
            } else {
                moreMenu
            }
        }
    }

    private var moreMenu: some View {
        Menu {
            Button("Rotate update token", systemImage: "key") { confirm = .rotate }
            Divider()
            Button("Reset domain", systemImage: "arrow.counterclockwise", role: .destructive) { askTyped(.reset) }
            Button("Delete domain", systemImage: "trash", role: .destructive) { askTyped(.delete) }
        } label: {
            Label("More actions", systemImage: "ellipsis")
        }
        .disabled(detail == nil)
    }

    // MARK: Confirmations

    private var confirmTitle: String {
        switch confirm {
        case .setIP: String(localized: "Update DNS record?")
        case .rotate: String(localized: "Rotate update token?")
        case .reset: String(localized: "Reset domain?")
        case .delete: String(localized: "Delete domain?")
        case .deleteRecord: String(localized: "Delete DNS record?")
        case nil: ""
        }
    }

    private func confirmMessage(_ confirm: DetailConfirm) -> String {
        switch confirm {
        case .setIP:
            String(localized: "You can't undo this action. This will permanently change the A or AAAA DNS record from your domain.")
        case .rotate:
            String(localized: "A new update token is created and the old one stops working immediately. Routers and scripts using the old update URL stop updating until you enter the new URL.")
        case .reset:
            String(localized: "All active DNS records of \(name) are deleted and the zone is set up anew. This cannot be undone. Type the domain name to confirm.")
        case .delete:
            String(localized: "Do you really want to delete \(name) with all its DNS records? Type the domain name to confirm.")
        case .deleteRecord(let record):
            String(localized: "Do you really want to delete the \(record.type?.rawValue ?? "?") record \"\(DynDNSLogic.prefixLabel(record.prefix))\" (\(record.content ?? "–"))?")
        }
    }

    @ViewBuilder private func confirmActions(_ confirm: DetailConfirm) -> some View {
        switch confirm {
        case .setIP:
            Button("Update") { run(setToCurrentIP) }
        case .rotate:
            Button("Rotate", role: .destructive) { run(rotate) }
        case .reset:
            TextField(name, text: $typedName).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Reset", role: .destructive) { run(reset) }.disabled(typedName != name)
        case .delete:
            TextField(name, text: $typedName).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Delete", role: .destructive) { run(deleteDomain) }.disabled(typedName != name)
        case .deleteRecord(let record):
            Button("Delete", role: .destructive) { Task { await deleteRecord(record) } }
        }
        Button("Cancel", role: .cancel) {}
    }

    private func askTyped(_ request: DetailConfirm) {
        typedName = ""
        confirm = request
    }

    // MARK: Loading and actions

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let api = session.api
        async let v4 = session.myIP(.v4)
        async let v6 = session.myIP(.v6)
        do {
            detail = try await ipv64Retrying { try await api.domains.get(name) }
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
        myV4 = await v4 ?? DynDNSLogic.noIPv4
        myV6 = await v6 ?? DynDNSLogic.noIPv6
    }

    private func changed() {
        onChanged()
        reloadToken += 1
    }

    private func run(_ work: @escaping () async throws -> Void) {
        Task {
            busy = true
            defer { busy = false }
            do {
                try await work()
            } catch is CancellationError {
            } catch {
                self.error = ErrorText(error)
            }
        }
    }

    private func copyUpdateURL() {
        guard let updateURL else { return }
        UIPasteboard.general.setItems([["public.utf8-plain-text": updateURL]],
                                      options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
        copied += 1
    }

    private func setToCurrentIP() async throws {
        let v4 = mismatchV4 ? DynDNSLogic.knownIp(myV4) : nil
        let v6 = mismatchV6 ? DynDNSLogic.knownIp(myV6) : nil
        let result = try await session.api.domains.updateDynDNS(name, ipv4: v4, ipv6: v6)
        let failed = (result.results ?? []).filter { DynDNSLogic.isFailure($0.result) }
        if !failed.isEmpty {
            error = ErrorText(title: String(localized: "Update error"), message: failed.map {
                "\($0.type?.rawValue ?? "") \($0.ip ?? ""): \(DynDNSLogic.outcomeLabel($0.result))"
            }.joined(separator: "\n"))
        }
        changed()
    }

    private func rotate() async throws {
        let rotated = try await session.api.domains.rotateToken(name)
        changed()
        if let url = DynDNSLogic.updateURL(token: rotated.updateToken) {
            sheet = .rotated(url)
        }
    }

    private func reset() async throws {
        detail = try await ipv64Retrying { try await session.api.domains.reset(name) }
        changed()
    }

    private func deleteDomain() async throws {
        do {
            try await session.api.domains.delete(name)
            onChanged()
            dismiss()
        } catch let e as IPv64Error where e.statusCode == 409 {
            var text = String(localized: "DNS failover is active for this domain. Remove or pause the failover policy first.")
            if case .api(let problem) = e, let detail = problem.detail.nonBlank { text = detail }
            error = ErrorText(title: String(localized: "Domain cannot be deleted"), message: text)
        }
    }

    /// The row disappears at once; on failure it comes back with the error.
    private func deleteRecord(_ record: Record) async {
        _ = withAnimation { deletedRecordIds.insert(record.id) }
        do {
            try await ipv64Retrying { try await session.api.records.delete(String(record.id)) }
            changed()
        } catch {
            _ = withAnimation { deletedRecordIds.remove(record.id) }
            self.error = ErrorText(error)
        }
    }
}

/// One DNS record: tap edits, swipe deletes; CDN/failover records are locked.
struct DomainRecordRow: View {
    let record: Record
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var locked: Bool { DynDNSLogic.isLocked(record.state) }

    var body: some View {
        let row = HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: DynDNSLogic.prefixLabel(record.prefix)).font(.headline)
                Text(verbatim: record.content ?? "–").font(.subheadline.monospaced()).lineLimit(3)
                Text(verbatim: "TTL \(record.ttl.map(String.init) ?? "–") · \(DynDNSLogic.germanTime(record.updatedAt))")
                    .font(.caption).foregroundStyle(.secondary)
                if let reason = DynDNSLogic.lockReason(record.state) {
                    Text(reason).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if record.pendingDNS == true {
                Text("DNS pending").font(.caption).foregroundStyle(.orange)
            } else if let state = record.state, state != .active, let label = DynDNSLogic.stateLabel(state) {
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            if locked {
                Image(systemName: "lock.fill").foregroundStyle(.secondary).accessibilityLabel("Locked")
            }
        }
        .contentShape(Rectangle())

        if locked {
            row
        } else {
            row
                .onTapGesture(perform: onEdit)
                .accessibilityAddTraits(.isButton)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                }
        }
    }
}
