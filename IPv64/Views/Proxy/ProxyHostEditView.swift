import SwiftUI
import IPv64

/// Pushed from Proxy64: one proxy host of a node. `hostId == nil` creates a host.
struct ProxyHostRoute: Hashable, Identifiable {
    let nodeId: String
    let hostId: Int?
    var id: String { "\(nodeId)/\(hostId.map(String.init) ?? "new")" }
}

/// Proxy host editor: header, actions, host/target/options/advanced; save, delete.
struct ProxyHostEditView: View {
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(\.dismiss) private var dismiss

    let route: ProxyHostRoute
    /// Tells Proxy64 that this node changed.
    let onChanged: () -> Void

    @State private var loaded: Node64.ProxyHost?
    @State private var didLoad = false
    @State private var form = ProxyHostForm()
    @State private var accessLists: [Int: String] = [:]
    @State private var certificates: [Int: String] = [:]
    @State private var cdnName: Node64.CDNOnlineName?
    @State private var edges: [Node64.CDNOnlineEdge] = []
    @State private var advanced = false
    @State private var submitted = false
    @State private var showMode = false
    @State private var confirm: Confirm?
    @State private var busy = false
    @State private var error: ErrorText?

    private enum Confirm { case delete, disableCdn }

    private var hostId: Int? { route.hostId }
    private var create: Bool { hostId == nil }
    private var ready: Bool { create || loaded != nil }

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(showMode || confirm != nil || error != nil ? .clear : .orange)
        } else { content }
    }

    private var content: some View {
        Form {
            if let loaded, !create {
                Section { ProxyHostRow(host: loaded, cdn: cdnName, edges: edges) }
                actions(loaded)
            }
            ProxyHostFormSections(form: $form, errors: submitted ? form.errors : nil, create: create,
                                  offersDefaultTLS: loaded?.minTLS == nil,
                                  accessLists: accessLists, certificates: certificates, advanced: $advanced)
        }
        .disabled(busy || !didLoad)
        .overlay { if !didLoad { ProgressView() } }
        .navigationTitle(create ? "New proxy host" : "Proxy host")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showMode) {
            CdnModeSheet(hostLabel: form.firstName.nonBlank) { mode, healthcheck in
                await enableCdn(mode: mode, healthcheck: healthcheck)
            }
        }
        .alert(confirm == .delete ? "Delete proxy host?" : "Disable CDN64?",
               isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }), presenting: confirm) { item in
            switch item {
            case .delete: Button("Delete", role: .destructive) { Task { await delete() } }
            case .disableCdn: Button("Disable", role: .destructive) { Task { await disableCdn() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            switch item {
            case .delete: Text("\(form.firstName) will be removed from the node.")
            case .disableCdn: Text("\(form.firstName) will no longer be reachable via the CDN64 servers.")
            }
        }
        .errorAlert($error)
        .task { await load() }
    }

    private func actions(_ host: Node64.ProxyHost) -> some View {
        let on = host.enabled != false
        return Section {
            Button { Task { await toggleEnabled(on: on) } } label: {
                Label(on ? "Disable host" : "Enable host", systemImage: on ? "pause.circle" : "play.circle")
            }
            Button { toggleCdn() } label: {
                Label(cdnName == nil ? "Enable CDN64" : "Disable CDN64", systemImage: cdnName == nil ? "icloud" : "icloud.slash")
            }
        }
        .tint(.primary)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if !create {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", systemImage: "trash", role: .destructive) { confirm = .delete }
                    .tint(.red)
                    .disabled(busy || loaded == nil)
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if busy {
                ProgressView()
            } else {
                // Enabled once the host is loaded (never save before: it would overwrite the names);
                // invalid input is reported inline and in an alert on tap.
                Button("Save", systemImage: "checkmark") { Task { await save() } }
                    .disabled(!ready || !didLoad)
            }
        }
    }

    // MARK: Actions

    private func run(_ block: (Node64) async throws -> Void) async {
        guard let node = nodes.client(for: route.nodeId) else {
            error = ErrorText(title: String(localized: "No access"), message: String(localized: "No access saved for this node."))
            return
        }
        busy = true
        defer { busy = false }
        do {
            try await block(node)
        } catch is CancellationError {
        } catch {
            self.error = ErrorText.node(error)
        }
    }

    private func load() async {
        await run { node in
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
        let status = try? await node.proxy64.online.status()
        cdnName = status?.names?.first { $0.hostID == hostId }
        edges = status?.edges ?? []
    }

    private func save() async {
        submitted = true
        if let message = form.errors.first {
            error = ErrorText(title: String(localized: "Check your input"), message: message)
            return
        }
        let input = form.input(create: create)
        await run { node in
            if let hostId { _ = try await node.proxy64.hosts.update(hostId, input) } else { _ = try await node.proxy64.hosts.create(input) }
            onChanged()
            dismiss()
        }
    }

    private func delete() async {
        guard let hostId else { return }
        await run { node in
            try await node.proxy64.hosts.delete(hostId)
            onChanged()
            dismiss()
        }
    }

    private func toggleEnabled(on: Bool) async {
        guard let hostId else { return }
        await run { node in
            loaded = on ? try await node.proxy64.hosts.disable(hostId) : try await node.proxy64.hosts.enable(hostId)
            onChanged()
        }
    }

    private func toggleCdn() {
        if cdnName == nil { showMode = true } else { confirm = .disableCdn }
    }

    private func disableCdn() async {
        guard let hostId else { return }
        await run { node in
            try await node.proxy64.online.disable(host: hostId)
            await refreshCdn(node, hostId)
            onChanged()
        }
    }

    private func enableCdn(mode: Int, healthcheck: Bool) async {
        guard let hostId else { return }
        let choice = CdnHostChoice(nodeId: route.nodeId, nodeName: "", hostId: hostId, label: form.firstName)
        busy = true
        defer { busy = false }
        if let failure = await nodes.enableCdn64(choice, mode: mode, healthcheck: healthcheck) { error = failure }
        if let node = nodes.client(for: route.nodeId) { await refreshCdn(node, hostId) }
        onChanged()
    }
}
