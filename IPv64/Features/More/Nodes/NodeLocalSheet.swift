import SwiftUI
import IPv64

/// Direct access sheet (spec 04 §3), presented via router.sheet = .directAccess(nodeId:).
struct NodeLocalSheet: View {
    @Environment(Session.self) private var session
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    /// `nil` = connect a new node.
    let nodeId: String?

    @State private var address = ""
    @State private var apiKey = ""
    @State private var error: String?
    @State private var isBusy = false
    @State private var message: ErrorText?
    @State private var savedId: String?
    @State private var storedKeyExists = false

    private var isNew: Bool { nodeId == nil }

    var body: some View {
        NodeFormSheet(title: isNew ? "Connect directly" : "Direct access", confirmLabel: "Connect",
                      confirmSystemImage: "network",
                      confirmEnabled: !address.nonBlankTrimmed.isEmpty && (!apiKey.nonBlankTrimmed.isEmpty || storedKeyExists),
                      isBusy: isBusy, onConfirm: { Task { await connect() } }) {
            Section {
                Text(isNew ? "Add a node without linking it to your account: connect to it by its local IP or by its link (e.g. https://node.example.com/api). Create an API key in the node's web interface on the API tab."
                     : "Connect directly to this node by its local IP or by its link (e.g. https://node.example.com/api). Create an API key in the node's web interface on the API tab.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                TextField("http://192.168.1.10:8080/api", text: $address)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Address")
            } footer: {
                Text("Local or public IP (http, port 8080 added) or link (https); /api is added if missing.")
            }
            Section {
                SecureField("node64_…", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("API key")
            } footer: {
                if storedKeyExists { Text("Leave empty to keep the saved key.") }
            }
            warning
        }
        .onChange(of: address) { error = nil }
        .onChange(of: apiKey) { error = nil }
        .task { load() }
        .errorAlert($message)
        .onChange(of: message) { if message == nil, let savedId { Task { await finish(savedId) } } }
    }

    @ViewBuilder private var warning: some View {
        switch insecureWarning(for: address) {
        case .none: EmptyView()
        case .local:
            Section { Text("The key is sent unencrypted on your local network.").font(.footnote).foregroundStyle(Color.ipv64Orange) }
        case .internet:
            Section {
                Text("The API key is sent unencrypted over the internet. Use https:// or a VPN if you can.")
                    .font(.footnote).foregroundStyle(Color.ipv64Red)
            }
        }
        if let error { Section { Text(verbatim: error).font(.footnote).foregroundStyle(Color.ipv64Red) } }
    }

    private func load() {
        guard let nodeId, let access = nodes.access(for: nodeId) else { return }
        if address.isEmpty { address = access.url }
        storedKeyExists = true
    }

    private func connect() async {
        guard let url = LocalNodeURL.normalizeLocalNodeUrl(address) else {
            error = LocalNodeURL.invalidInputMessage(address)
            return
        }
        let typed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = typed.isEmpty ? (nodeId.flatMap { nodes.access(for: $0)?.key } ?? "") : typed
        guard isValidNodeApiKey(key) else {
            error = String(localized: "The API key contains invalid characters.")
            return
        }
        address = url
        error = nil
        isBusy = true
        defer { isBusy = false }
        do {
            guard let client = NodeClientFactory.client(url: url, key: key) else {
                error = ErrorText.node(NodeTransportError(host: url)).titledText
                return
            }
            _ = try await client.node.health()
            let status = try await client.node.status()
            let remoteId = status.node?.id?.nonBlank
            if let nodeId {
                try LocalNodeStore.save(id: nodeId, url: url, key: key, owner: nodes.owner)
                if let modules = status.modules { LocalNodeStore.saveModules(nodeId, modules: modules) }
                apiKey = ""
                if let remoteId, remoteId != nodeId {
                    savedId = nodeId
                    message = ErrorText(
                        title: String(localized: "Different node?"),
                        message: String(localized: "The node at this address reports the ID \(remoteId) instead of \(nodeId). The connection was saved anyway — check the address if this is unexpected."))
                } else {
                    await finish(nodeId)
                }
            } else {
                guard let newId = remoteId else {
                    error = String(localized: "The node did not report its ID. Update Node64 and try again.")
                    return
                }
                try LocalNodeStore.save(id: newId, url: url, key: key, owner: nodes.owner, name: status.node?.name?.nonBlank)
                if let modules = status.modules { LocalNodeStore.saveModules(newId, modules: modules) }
                apiKey = ""
                await finish(newId)
            }
        } catch is CancellationError {
            return
        } catch {
            self.error = ErrorText.node(error).titledText
        }
    }

    /// Updates tabs, reloads the detail (or opens the new node) and closes the sheet.
    private func finish(_ id: String) async {
        nodes.refresh()
        await nodes.refreshModules()
        router.reload()
        if isNew { router.push(.nodeDetail(nodeId: id)) }
        dismiss()
    }
}

private extension String {
    var nonBlankTrimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
