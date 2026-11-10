import SwiftUI
import IPv64

/// Cloud CDN domain (spec 03 §10.1). 202 actions are followed by a cancellable poll (every 5 s, max 60 s).
struct CdnDetailView: View {
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    let token: String

    @State private var detail: CDNDomainDetail?
    @State private var notAvailable: String?
    @State private var records: [Record]?
    @State private var recordsExpanded = false
    @State private var accessList: [AccessListEntry]?
    @State private var accessExpanded = false
    @State private var sheet: DetailSheet?
    @State private var confirm: ConfirmRequest?
    @State private var pollRound = 0
    @State private var removed = false
    @State private var busy: LocalizedStringKey?
    @State private var error: ErrorText?

    private enum DetailSheet: Identifiable {
        case enableRecord(Record), mapping, address
        var id: String {
            switch self {
            case .enableRecord(let r): "record-\(r.id)"
            case .mapping: "mapping"
            case .address: "address"
            }
        }
    }

    private var enabled: Bool { busy == nil && detail != nil }
    private var taskRunning: Bool { detail?.isBusy == true }

    var body: some View {
        List {
            if let detail {
                CdnHeaderSections(detail: detail)
                CdnProxySection(
                    detail: detail, enabled: enabled, lockTasks: taskRunning,
                    toggleProxy: { toggleProxy(on: detail.proxy?.state == .on) }, renew: renew,
                    settings: { router.push(.cdnSettings(token: token)) })
                CdnPortmapperSection(
                    detail: detail, enabled: enabled, lockTasks: taskRunning,
                    toggle: { togglePortmapper(on: detail.portmapper?.state == .on) },
                    addMapping: { Task { await addMapping() } }, deleteMapping: askDeleteMapping)
                CdnRecordsSection(expanded: $recordsExpanded, records: records, enabled: busy == nil,
                                  refresh: { Task { await loadRecords() } },
                                  enable: { sheet = .enableRecord($0) }, disable: askDisableRecord)
                CdnAccessSection(expanded: $accessExpanded, entries: accessList, settingsText: accessText(detail),
                                 enabled: busy == nil, refresh: { Task { await loadAccessList() } },
                                 add: { sheet = .address }, remove: askRemoveAddress)
            }
        }
        .navigationTitle(detail?.displayName ?? String(localized: "CDN domain"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if let notAvailable { NotAvailableView(feature: "CDN", reason: notAvailable) }
            else if detail == nil { LoadingView() }
        }
        .refreshable { await load() }
        .task(id: router.reloadToken) { await load() }
        .task(id: pollRound) { if pollRound > 0 { await poll() } }
        .onChange(of: recordsExpanded) { if recordsExpanded && records == nil { Task { await loadRecords() } } }
        .onChange(of: accessExpanded) { if accessExpanded && accessList == nil { Task { await loadAccessList() } } }
        .toolbar { toolbar }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .enableRecord(let record):
                CdnEnableRecordSheet(record: record) { mode in Task { await enable(record, mode: mode) } }
            case .mapping:
                CdnMappingSheet(records: (records ?? []).filter(\.canDisableCdn)) { input in
                    Task { await createMapping(input) }
                }
            case .address:
                CdnAddAddressSheet { address in Task { await addAddress(address) } }
            }
        }
        .confirmDialog($confirm)
        .loadingOverlay(busy != nil, text: busy ?? "")
        .errorAlert($error)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Settings", systemImage: "pencil") { router.push(.cdnSettings(token: token)) }.disabled(!enabled)
        }
        AppMoreMenu(disabled: !enabled) {
            Button("Redeploy configuration", systemImage: "arrow.triangle.2.circlepath") {
                act("Redeploying...", always: true) { api in _ = try await api.cdn.redeploy(token) }
            }
            .disabled(taskRunning)
            Button("Move to another server", systemImage: "arrow.left.arrow.right") { askMove() }.disabled(taskRunning)
            Button("Reset traffic counters", systemImage: "gobackward") { askReset() }
            Button("Remove from CDN", systemImage: "trash", role: .destructive) { askRemove() }.disabled(taskRunning)
        }
    }

    private func accessText(_ detail: CDNDomainDetail) -> String {
        let acl = detail.proxy?.accessList
        return acl?.enabled == true
            ? String(localized: "Active. \(acl?.mode?.label ?? String(localized: "Unknown")).")
            : String(localized: "Currently switched off. Turn it on in the settings.")
    }

    // MARK: Loading and polling

    /// Reads the domain; 404 means it was removed (leave the screen).
    private func fetch() async throws {
        do {
            detail = try await ipv64Retrying { try await session.api.cdn.get(token) }
        } catch let e as IPv64Error where e.isNotFound && detail != nil {
            leaveRemoved()
        }
    }

    /// The domain is gone from the CDN: refresh the lists and leave (once).
    private func leaveRemoved() {
        guard !removed else { return }
        removed = true
        router.reload()
        router.pop()
    }

    private func load() async {
        guard !removed else { return }
        notAvailable = nil
        do {
            try await fetch()
            if detail?.isBusy == true { pollRound += 1 }
        } catch {
            if let e = error as? IPv64Error, e.isPlanRestricted { notAvailable = e.planRestrictionText }
            else if !isCancellation(error) { self.error = ErrorText(error) }
        }
    }

    private func poll() async {
        do {
            let result = try await pollUntil(
                interval: .seconds(5), max: .seconds(60),
                onEach: { (d: CDNDomainDetail?) in if let d { detail = d } },
                fetch: { () async throws -> CDNDomainDetail? in
                    do { return try await session.api.cdn.get(token) } catch let e as IPv64Error where e.isNotFound { return nil }
                },
                done: { $0 == nil || $0?.isBusy == false })
            switch result {
            case .none:
                error = ErrorText(title: String(localized: "Still working"),
                                  message: String(localized: "The CDN needs longer than expected. Pull down to refresh later."))
            case .some(.none):
                leaveRemoved()
            case .some(.some):
                if records != nil { await loadRecords(spinner: false) }
            }
        } catch {
            if !isCancellation(error) { self.error = ErrorText(error) }
        }
    }

    /// Runs an action (202 or 200), re-reads the domain and watches open work.
    private func act(_ spinner: LocalizedStringKey, always: Bool = false, _ block: @escaping (IPv64) async throws -> Void) {
        Task {
            busy = spinner
            defer { busy = nil }
            do {
                try await block(session.api)
                try await fetch()
                if always || detail?.isBusy == true { pollRound += 1 }
            } catch {
                if !isCancellation(error) { self.error = ErrorText(error) }
            }
        }
    }

    private func toggleProxy(on: Bool) {
        if on { act("Switching proxy off...", always: true) { api in _ = try await ipv64Retrying { try await api.cdn.disableProxy(token) } } }
        else { act("Switching proxy on...", always: true) { api in _ = try await ipv64Retrying { try await api.cdn.enableProxy(token) } } }
    }

    private func togglePortmapper(on: Bool) {
        if on { act("Switching port mapper off...", always: true) { api in _ = try await ipv64Retrying { try await api.cdn.disablePortmapper(token) } } }
        else { act("Switching port mapper on...", always: true) { api in _ = try await ipv64Retrying { try await api.cdn.enablePortmapper(token) } } }
    }

    private func renew() {
        act("Renewing certificate...", always: true) { api in _ = try await ipv64Retrying { try await api.cdn.renewCertificate(token) } }
    }

    // MARK: Records, access list, mappings

    private func loadRecords(spinner: Bool = true) async {
        if spinner { busy = "Loading records..." }
        defer { if spinner { busy = nil } }
        do {
            records = try await ipv64Retrying { try await session.api.cdn.records.list(cdn: token) }
        } catch {
            if !isCancellation(error) { self.error = ErrorText(error) }
        }
    }

    private func loadAccessList() async {
        busy = "Loading access list..."
        defer { busy = nil }
        do {
            accessList = try await ipv64Retrying { try await session.api.cdn.accessList.list(cdn: token) }
        } catch {
            if !isCancellation(error) { self.error = ErrorText(error) }
        }
    }

    private func enable(_ record: Record, mode: CDNRecordMode) async {
        busy = "Updating record..."
        defer { busy = nil }
        do {
            let updated = try await ipv64Retrying { try await session.api.cdn.records.enable(String(record.id), cdn: token, mode: mode) }
            records = records?.map { $0.id == updated.id ? updated : $0 }
            pollRound += 1
        } catch {
            if !isCancellation(error) { self.error = ErrorText(error) }
        }
    }

    private func disable(_ record: Record) async {
        busy = "Updating record..."
        defer { busy = nil }
        do {
            let updated = try await ipv64Retrying { try await session.api.cdn.records.disable(String(record.id), cdn: token) }
            records = records?.map { $0.id == updated.id ? updated : $0 }
            pollRound += 1
        } catch {
            if !isCancellation(error) { self.error = ErrorText(error) }
        }
    }

    private func addMapping() async {
        if records == nil { await loadRecords() }
        guard let records else { return }
        if records.contains(where: \.canDisableCdn) {
            sheet = .mapping
        } else {
            error = ErrorText(title: String(localized: "Add port mapping"),
                              message: String(localized: "No record runs through the CDN yet. Enable the CDN for an A or AAAA record first."))
        }
    }

    private func createMapping(_ input: CdnMappingInput) async {
        busy = "Adding mapping..."
        defer { busy = nil }
        do {
            _ = try await ipv64Retrying {
                try await session.api.cdn.mappings.create(cdn: token, record: input.record, targetPort: input.targetPort,
                                                          transport: input.transport, name: input.name, listenPort: input.listenPort)
            }
            try await fetch()
        } catch {
            if !isCancellation(error) { self.error = ErrorText(error) }
        }
    }

    private func addAddress(_ address: String) async {
        busy = "Adding..."
        defer { busy = nil }
        do {
            let entry = try await ipv64Retrying { try await session.api.cdn.accessList.add(cdn: token, address: address) }
            accessList = (accessList ?? []) + [entry]
        } catch {
            if !isCancellation(error) { self.error = ErrorText(error) }
        }
    }

    // MARK: Confirmations (verbatim Android texts)

    private func askMove() {
        confirm = ConfirmRequest(
            title: String(localized: "Move to another server?"),
            message: String(localized: "The domain is moved to another CDN server. The IP addresses of the CDN change and DNS caches may keep pointing to the old server for a while."),
            confirmLabel: String(localized: "Move"), destructive: true
        ) { act("Moving...", always: true) { api in _ = try await ipv64Retrying { try await api.cdn.move(token) } } }
    }

    private func askReset() {
        confirm = ConfirmRequest(
            title: String(localized: "Reset traffic counters?"),
            message: String(localized: "The traffic counters of this domain are set back to zero. This cannot be undone."),
            confirmLabel: String(localized: "Reset"), destructive: true
        ) { act("Resetting...") { api in _ = try await ipv64Retrying { try await api.cdn.resetTraffic(token) } } }
    }

    private func askRemove() {
        let name = detail?.displayName ?? ""
        confirm = ConfirmRequest(
            title: String(localized: "Remove from CDN?"),
            message: String(localized: "\"\(name)\" is removed from the CDN with its port mappings and access list. The CDN must be disabled for all records first, otherwise the server rejects this. This cannot be undone."),
            confirmLabel: String(localized: "Remove"), destructive: true, requireTyping: detail?.domain
        ) { act("Removing...", always: true) { api in _ = try await ipv64Retrying { try await api.cdn.delete(token) } } }
    }

    private func askDisableRecord(_ record: Record) {
        confirm = ConfirmRequest(
            title: String(localized: "Deliver record directly?"),
            message: String(localized: "\(record.cdnTitle) is no longer routed through the CDN. Visitors reach your server directly again once DNS caches expire, and your server's IP address becomes visible."),
            confirmLabel: String(localized: "Disable CDN"), destructive: true
        ) { Task { await disable(record) } }
    }

    private func askDeleteMapping(_ mapping: CDNMapping) {
        confirm = ConfirmRequest(
            title: String(localized: "Delete port mapping?"),
            message: String(localized: "Public port \(mapping.listenPort.map(String.init) ?? "–") no longer forwards to port \(mapping.targetPort.map(String.init) ?? "–")."),
            confirmLabel: String(localized: "Delete"), destructive: true
        ) {
            act("Deleting...") { api in
                try await ipv64Retrying { try await api.cdn.mappings.delete(mapping.id, cdn: token) }
            }
        }
    }

    private func askRemoveAddress(_ entry: AccessListEntry) {
        confirm = ConfirmRequest(
            title: String(localized: "Remove address?"),
            message: String(localized: "\"\(entry.address ?? "")\" is removed from the access list. Depending on the list mode, this address may lose access to the site, or it may be blocked, which can lock you out."),
            confirmLabel: String(localized: "Remove"), destructive: true
        ) {
            Task {
                busy = "Removing..."
                defer { busy = nil }
                do {
                    try await ipv64Retrying { try await session.api.cdn.accessList.delete(entry.id, cdn: token) }
                    accessList = accessList?.filter { $0.id != entry.id }
                } catch {
                    if !isCancellation(error) { self.error = ErrorText(error) }
                }
            }
        }
    }
}
