import SwiftUI
import IPv64

/// "API keys": list, delete, create (the new key is shown once).
struct ApiKeysView: View {
    @Environment(Session.self) private var session

    @State private var keys: [APIKey] = []
    @State private var auth: Me.Auth?
    @State private var loaded = false
    @State private var busy = false
    @State private var error: ErrorText?
    @State private var showCreate = false
    @State private var pendingSecret: APIKeyCreated?
    @State private var secret: APIKeyCreated?
    @State private var deleteKey: APIKey?

    private var currentKeyId: Int? { auth?.type == .apiKey ? auth?.keyID : nil }

    var body: some View {
        content
            .moreGradient(sheetShown: showCreate || secret != nil)
    }

    private var content: some View {
        List {
            if loaded {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: infoTitle)
                            Text("A new key is shown only once after creating it. Keys give full access to your account; delete keys you no longer use.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "key")
                    }
                }
                if !keys.isEmpty {
                    Section("API keys (\(keys.count))") {
                        ForEach(keys) { row($0) }
                    }
                }
            }
        }
        .overlay {
            if !loaded && error == nil { ProgressView() }
            else if loaded && keys.isEmpty { ContentUnavailableView("No API keys yet.", systemImage: "key") }
        }
        .disabled(busy)
        .navigationTitle("API keys")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if loaded {
                ToolbarItem(placement: .primaryAction) {
                    if busy {
                        ProgressView()
                    } else {
                        Button("New API key", systemImage: "plus") { showCreate = true }
                    }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .alert("Delete API key?", isPresented: Binding(get: { deleteKey != nil }, set: { if !$0 { deleteKey = nil } }),
               presenting: deleteKey) { key in
            Button("Delete", role: .destructive) { Task { await delete(key) } }
            Button("Cancel", role: .cancel) {}
        } message: { key in
            Text("\"\(name(key))\" stops working immediately. Apps and scripts using it lose access.")
        }
        .sheet(isPresented: $showCreate, onDismiss: {
            secret = pendingSecret
            pendingSecret = nil
        }) {
            ApiKeyCreateSheet { created in
                Task { await load() }
                if created.token?.nonBlank == nil {
                    error = ErrorText(title: String(localized: "API key created"),
                                      message: String(localized: "The server did not return the key. Delete it and try again."))
                } else {
                    pendingSecret = created
                }
            }
        }
        .sheet(item: $secret) { created in
            ApiKeySecretSheet(key: created)
        }
        .errorAlert($error)
    }

    private var infoTitle: String {
        switch auth?.type {
        case .apiKey:
            let keyName = auth?.keyName?.nonBlank ?? "#" + (auth?.keyID.map(String.init) ?? "?")
            return String(localized: "This app uses the API key \"\(keyName)\".")
        case .accountKey: return String(localized: "This app uses your account key.")
        default: return String(localized: "This app's key type is unknown.")
        }
    }

    private func name(_ key: APIKey) -> String { key.name?.nonBlank ?? String(localized: "Unnamed key") }

    private func row(_ key: APIKey) -> some View {
        let current = key.id == currentKeyId
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: name(key)).font(.headline)
                Spacer(minLength: 8)
                if current { MoreTag(String(localized: "This app"), .blue) }
                if key.expired == true { MoreTag(String(localized: "Expired"), .red) }
            }
            Text(verbatim: ApiKeyText.subtitle(key, current: current))
                .font(.footnote.monospaced()).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !current {
                Button("Delete API key", systemImage: "trash", role: .destructive) { deleteKey = key }
                    .labelStyle(.iconOnly)
                    .tint(.red)
            }
        }
    }

    private func delete(_ key: APIKey) async {
        busy = true
        defer { busy = false }
        do {
            try await session.api.apiKeys.delete(key.id)
            keys.removeAll { $0.id == key.id }
        } catch let failure as IPv64Error where failure.statusCode == 409 {
            var detail = String(localized: "This key is used by this app and cannot be deleted.")
            if case .api(let problem) = failure, let text = problem.detail.nonBlank { detail = text }
            error = ErrorText(title: String(localized: "Key in use"), message: detail)
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func load() async {
        do {
            let me = try await session.api.account.me()
            auth = me.auth
            keys = try await session.api.apiKeys.list()
            loaded = true
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }
}

/// "New API key" form sheet. Calls `onCreated` with the created key (including its one-time token).
struct ApiKeyCreateSheet: View {
    let onCreated: (APIKeyCreated) -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var validity = ApiKeyText.defaultValidity
    @State private var busy = false
    @State private var error: ErrorText?

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        DynDNSSheet(title: "New API key", confirmLabel: "Create", confirmEnabled: !trimmed.isEmpty,
                    isBusy: busy, onConfirm: { Task { await create() } }) {
            Section {
                TextField("Name", text: $name, prompt: Text("e.g. Home Assistant"))
                    .onChange(of: name) { _, new in
                        if new.count > ApiKeyText.nameLimit { name = String(new.prefix(ApiKeyText.nameLimit)) }
                    }
            } footer: {
                Text(verbatim: "\(name.count) / \(ApiKeyText.nameLimit)")
            }
            Section {
                Picker("Valid for", selection: $validity) {
                    ForEach(ApiKeyText.validity, id: \.seconds) { Text(verbatim: $0.label).tag($0.seconds) }
                }
            }
        }
        .errorAlert($error)
        .presentationDetents([.medium, .large])
    }

    private func create() async {
        busy = true
        defer { busy = false }
        do {
            let created = try await session.api.apiKeys.create(name: trimmed, expiresIn: validity)
            onCreated(created)
            dismiss()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }
}

/// Shows the new key exactly once; it cannot be swiped away, only closed with "Done".
struct ApiKeySecretSheet: View {
    let key: APIKeyCreated

    var body: some View {
        DynDNSSheet(title: "New API key") {
            Section {
                Label("Copy the key now and store it securely. It is shown only once and cannot be retrieved later.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if let token = key.token?.nonBlank {
                Section("Key") {
                    Text(verbatim: token).font(.body.monospaced()).textSelection(.enabled)
                    Button("Copy key", systemImage: "document.on.document") { Clipboard.copy(token, sensitive: true) }
                }
            }
        }
        .interactiveDismissDisabled()
        .presentationDetents([.medium])
    }
}
