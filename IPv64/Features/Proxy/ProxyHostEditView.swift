import SwiftUI
import IPv64

/// Proxy host editor (spec 03 §5). `hostId == nil` creates a host.
struct ProxyHostEditView: View {
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(Router.self) private var router

    let nodeId: String
    /// `nil` = new proxy host.
    let hostId: Int?

    @State private var loaded: Node64.ProxyHost?
    @State private var didLoad = false
    @State private var form = ProxyHostForm()
    @State private var accessLists: [Int: String] = [:]
    @State private var certificates: [Int: String] = [:]
    @State private var cdnName: Node64.CDNOnlineName?
    @State private var inlineError: String?
    @State private var showMode = false
    @State private var confirm: ConfirmRequest?
    @State private var busy: LocalizedStringKey?
    @State private var error: ErrorText?

    private var create: Bool { hostId == nil }
    /// Never save before the host is loaded (would overwrite its names).
    private var canSave: Bool { busy == nil && (create || loaded != nil) }

    var body: some View {
        Form {
            if let loaded, !create {
                Section { ProxyHostRow(host: loaded, cdn: cdnName) }
                Section {
                    HostActionTiles(enabled: loaded.enabled != false, inCdn: cdnName != nil, disabled: busy != nil,
                                    toggleEnabled: toggleEnabled, toggleCdn: toggleCdn)
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            ProxyHostFormSections(form: $form, inlineError: $inlineError, create: create,
                                  offersDefaultTLS: loaded?.minTLS == nil,
                                  accessLists: accessLists, certificates: certificates)
            if let inlineError {
                Section { Text(verbatim: inlineError).foregroundStyle(Color.ipv64Red) }
            }
        }
        .navigationTitle("Proxy host")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if !didLoad && !create { LoadingView() } }
        .toolbar {
            if !create {
                ToolbarItem(placement: .primaryAction) {
                    Button("Delete", systemImage: "trash", role: .destructive, action: askDelete)
                        .disabled(busy != nil || loaded == nil)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(create ? "Create" : "Save", systemImage: "checkmark") { Task { await save() } }
                    .disabled(!canSave)
            }
            .appVisibilityPriorityHigh()
        }
        .sheet(isPresented: $showMode) {
            CdnModeSheet(hostLabel: form.firstName.nonBlank) { mode, healthcheck in
                Task { await enableCdn(mode: mode, healthcheck: healthcheck) }
            }
        }
        .confirmDialog($confirm)
        .loadingOverlay(busy != nil, text: busy ?? "")
        .errorAlert($error)
        .task { await load() }
    }

    // MARK: Actions

    private func run(_ spinner: LocalizedStringKey, _ block: (Node64) async throws -> Void) async {
        guard let node = nodes.client(for: nodeId) else {
            error = ErrorText(title: String(localized: "No access"), message: String(localized: "No access saved for this node."))
            return
        }
        busy = spinner
        defer { busy = nil }
        do {
            try await block(node)
        } catch {
            if !isCancellation(error) { self.error = ErrorText.node(error) }
        }
    }

    private func load() async {
        await run("Loading...") { node in
            if let hostId {
                let host = try await node.proxy64.hosts.get(hostId)
                loaded = host
                form = ProxyHostForm(host: host)
            }
            // Choices are optional: a failure only leaves them out.
            if let lists = try? await node.proxy64.accessLists.list() {
                accessLists = Dictionary(lists.compactMap { $0.accessList }.map { ($0.id, $0.name ?? "#\($0.id)") },
                                         uniquingKeysWith: { a, _ in a })
            }
            if let certs = try? await node.certificates.list() {
                certificates = Dictionary(certs.map { ($0.id, ($0.names ?? []).joined(separator: ", ").nonBlank ?? "#\($0.id)") },
                                          uniquingKeysWith: { a, _ in a })
            }
            if let hostId { await refreshCdn(node, hostId) }
        }
        didLoad = true
    }

    private func refreshCdn(_ node: Node64, _ hostId: Int) async {
        cdnName = try? await node.proxy64.online.status().names?.first { $0.hostID == hostId }
    }

    private func save() async {
        inlineError = form.validationError
        if let message = inlineError {
            error = ErrorText(title: String(localized: "Check your input"), message: String(localized: String.LocalizationValue(message)))
            return
        }
        let input = form.input(create: create)
        await run("Saving...") { node in
            if let hostId { _ = try await node.proxy64.hosts.update(hostId, input) } else { _ = try await node.proxy64.hosts.create(input) }
            router.reload()
            router.pop()
        }
    }

    private func askDelete() {
        confirm = ConfirmRequest(
            title: String(localized: "Delete proxy host?"),
            message: String(localized: "\(form.firstName) will be removed from the node."),
            confirmLabel: String(localized: "Delete"), destructive: true
        ) { Task { await delete() } }
    }

    private func delete() async {
        guard let hostId else { return }
        await run("Deleting...") { node in
            try await node.proxy64.hosts.delete(hostId)
            router.reload()
            router.pop()
        }
    }

    private func toggleEnabled() {
        guard let hostId, let loaded else { return }
        let on = loaded.enabled != false
        Task {
            await run(on ? "Disabling..." : "Enabling...") { node in
                self.loaded = on ? try await node.proxy64.hosts.disable(hostId) : try await node.proxy64.hosts.enable(hostId)
                router.reload()
            }
        }
    }

    private func toggleCdn() {
        guard let hostId else { return }
        if cdnName == nil {
            showMode = true
            return
        }
        Task {
            await run("Disabling CDN64...") { node in
                try await node.proxy64.online.disable(host: hostId)
                await refreshCdn(node, hostId)
                router.reload()
            }
        }
    }

    private func enableCdn(mode: Int, healthcheck: Bool) async {
        guard let hostId else { return }
        await run("Enabling CDN64...") { node in
            if let text = try await node.enableCdn64(host: hostId, mode: mode, healthcheck: healthcheck) {
                error = ErrorText(title: "CDN64", message: text)
            }
            await refreshCdn(node, hostId)
            router.reload()
        }
    }
}

private struct HostActionTiles: View {
    let enabled: Bool
    let inCdn: Bool
    let disabled: Bool
    let toggleEnabled: () -> Void
    let toggleCdn: () -> Void

    var body: some View {
        ActionTileRow {
            ActionTile(enabled ? "Disable" : "Enable", systemImage: enabled ? "pause" : "play", action: toggleEnabled)
            ActionTile(inCdn ? "Disable CDN64" : "Enable CDN64", systemImage: inCdn ? "icloud.slash" : "icloud", action: toggleCdn)
        }
        .disabled(disabled)
    }
}
