import SwiftUI
import IPv64

/// Direct access to a node by address and node API key (Android `NodeLocalSheet`).
/// `nodeId == nil` connects a new node, otherwise it edits the stored access of that node.
struct NodeLocalSheet: View {
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(\.dismiss) private var dismiss
    var nodeId: String?

    @State private var address = ""
    @State private var apiKey = ""
    @State private var inlineError: String?
    @State private var isConnecting = false
    @State private var storedKeyExists = false
    @State private var differentNode: DifferentNode?

    private struct DifferentNode {
        let id: String
        let remoteId: String
    }

    private var isNew: Bool { nodeId == nil }

    /// Normalised address when it differs from the input (shown under the field).
    private var preview: String? {
        guard let url = LocalNodeURL.normalizeLocalNodeUrl(address),
              url != address.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return url
    }

    private var intro: String {
        isNew
            ? String(localized: "Add a node without linking it to your account: connect to it by its local IP or by its link (e.g. https://node.example.com/api). Create an API key in the node's web interface on the API tab.")
            : String(localized: "Connect directly to this node by its local IP or by its link (e.g. https://node.example.com/api). Create an API key in the node's web interface on the API tab.")
    }

    var body: some View {
        DynDNSSheet(title: isNew ? "Connect directly" : "Direct access", subtitle: intro, confirmLabel: "Connect",
                    confirmEnabled: address.nonBlank != nil && (apiKey.nonBlank != nil || storedKeyExists),
                    isBusy: isConnecting, onConfirm: { Task { await connect() } }) {
            Section {
                TextField("Address", text: $address, prompt: Text(verbatim: "http://192.168.1.10:8080/api"))
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Address")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local or public IP (http, port 8080 added) or link (https); /api is added if missing.")
                    if let preview { Text("Connects to \(preview)") }
                }
            }
            .disabled(isConnecting)
            Section {
                SecureField("API key", text: $apiKey, prompt: Text(verbatim: "node64_…"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("API key")
            } footer: {
                if storedKeyExists { Text("Leave empty to keep the saved key.") }
            }
            .disabled(isConnecting)
            warning
            if isConnecting {
                Section {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Connecting...").foregroundStyle(.secondary)
                    }
                }
            }
            if let inlineError {
                Section { Text(inlineError).font(.footnote).foregroundStyle(.red) }
            }
        }
        .onChange(of: address) { inlineError = nil }
        .onChange(of: apiKey) { inlineError = nil }
        .task { load() }
        .alert("Different node?", isPresented: Binding(get: { differentNode != nil }, set: { if !$0 { differentNode = nil } }),
               presenting: differentNode) { _ in
            Button("OK") { Task { await finish() } }
        } message: { node in
            Text("The node at this address reports the ID \(node.remoteId) instead of \(node.id). The connection was saved anyway — check the address if this is unexpected.")
        }
        .appReadableWidth()
        .presentationDetents([.large])
    }

    @ViewBuilder private var warning: some View {
        switch NodesLogic.insecureWarning(for: address) {
        case .none:
            EmptyView()
        case .local:
            Section { Text("The key is sent unencrypted on your local network.").font(.footnote).foregroundStyle(.orange) }
        case .internet:
            Section {
                Text("The API key is sent unencrypted over the internet. Use https:// or a VPN if you can.")
                    .font(.footnote).foregroundStyle(.red)
            }
        }
    }

    private func load() {
        guard let nodeId, let access = nodes.access(for: nodeId) else { return }
        if address.isEmpty { address = access.url }
        storedKeyExists = true
    }

    private func connect() async {
        guard let url = LocalNodeURL.normalizeLocalNodeUrl(address) else {
            inlineError = LocalNodeURL.invalidInputMessage(address)
            return
        }
        let typed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = typed.isEmpty ? (nodeId.flatMap { nodes.access(for: $0)?.key } ?? "") : typed
        guard NodesLogic.isValidApiKey(key) else {
            inlineError = String(localized: "The API key contains invalid characters.")
            return
        }
        guard let client = NodeClientFactory.client(url: url, key: key) else {
            inlineError = LocalNodeURL.invalidInputMessage(address)
            return
        }
        address = url
        inlineError = nil
        isConnecting = true
        defer { isConnecting = false }
        do {
            _ = try await client.node.health()
            let status = try await client.node.status()
            let remoteId = status.node?.id?.nonBlank
            let id: String
            if let nodeId {
                id = nodeId
                try LocalNodeStore.save(id: nodeId, url: url, key: key, owner: nodes.owner)
            } else {
                guard let remoteId else {
                    inlineError = String(localized: "The node did not report its ID. Update Node64 and try again.")
                    return
                }
                id = remoteId
                try LocalNodeStore.save(id: remoteId, url: url, key: key, owner: nodes.owner, name: status.node?.name?.nonBlank)
            }
            if let modules = status.modules { LocalNodeStore.saveModules(id, modules: modules) }
            nodes.push(id)
            apiKey = ""
            if let remoteId, remoteId != id {
                differentNode = DifferentNode(id: id, remoteId: remoteId)
            } else {
                await finish()
            }
        } catch is CancellationError {
        } catch let error as SecureStore.StoreError {
            inlineError = error.localizedDescription
        } catch {
            inlineError = ErrorText.node(error).titledText
        }
    }

    /// Updates the tab flags, then closes the sheet.
    private func finish() async {
        isConnecting = true
        nodes.refresh()
        await nodes.refreshModules()
        isConnecting = false
        dismiss()
    }
}
