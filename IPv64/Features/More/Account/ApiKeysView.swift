import SwiftUI
import IPv64

/// "API keys" (spec 04 §8): list, delete, create (secret shown once).
struct ApiKeysView: View {
    @Environment(Session.self) private var session

    @State private var keys: [APIKey] = []
    @State private var auth: Me.Auth?
    @State private var loaded = false
    @State private var isLoading = false
    @State private var deleting = false
    @State private var error: ErrorText?
    @State private var showCreate = false
    @State private var pendingSecret: APIKeyCreated?
    @State private var secret: APIKeyCreated?
    @State private var confirm: ConfirmRequest?

    private var currentKeyId: Int? { auth?.type == .apiKey ? auth?.keyID : nil }

    var body: some View {
        List {
            if loaded {
                Section {
                    ListRow(verbatim: infoTitle, subtitle: String(localized: "A new key is shown only once after creating it. Keys give full access to your account; delete keys you no longer use."),
                            systemImage: "key", subtitleLineLimit: 4)
                }
                if keys.isEmpty {
                    Section { EmptyStateView("No API keys yet.") }
                } else {
                    Section("API keys (\(keys.count))") {
                        ForEach(keys) { key in row(key) }
                    }
                }
            }
        }
        .navigationTitle("API keys")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if loaded {
                ToolbarItem(placement: .primaryAction) {
                    Button("New API key", systemImage: "plus") { showCreate = true }
                }
                .appVisibilityPriorityHigh()
            }
        }
        .refreshable { await load() }
        .task(id: session.accountRevision) { await load() }
        .loadingOverlay(isLoading && !loaded, text: "Loading...")
        .loadingOverlay(deleting, text: "Deleting...")
        .errorAlert($error) { Task { await load() } }
        .confirmDialog($confirm)
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
            SecretOnceSheet(key: created) { secret = nil }
        }
    }

    private var infoTitle: String {
        switch auth?.type {
        case .apiKey:
            let name = auth?.keyName?.nonBlank ?? "#" + (auth?.keyID.map(String.init) ?? "?")
            return String(localized: "This app uses the API key \"\(name)\".")
        case .accountKey: return String(localized: "This app uses your account key.")
        default: return String(localized: "This app's key type is unknown.")
        }
    }

    private func row(_ key: APIKey) -> some View {
        let current = key.id == currentKeyId
        return ListRow(verbatim: key.name?.nonBlank ?? String(localized: "Unnamed key"),
                       subtitle: ApiKeyText.subtitle(key, current: current),
                       systemImage: "key", subtitleLineLimit: 6, monospacedSubtitle: true) {
            if current { StatusChip("This app", color: .ipv64Blue) }
            if key.expired == true { StatusChip("Expired", color: .ipv64Red) }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !current {
                Button("Delete API key", systemImage: "trash", role: .destructive) { askDelete(key) }
            }
        }
        .contextMenu {
            if !current { Button("Delete API key", systemImage: "trash", role: .destructive) { askDelete(key) } }
        }
    }

    private func askDelete(_ key: APIKey) {
        let name = key.name?.nonBlank ?? String(localized: "Unnamed key")
        confirm = ConfirmRequest(
            title: String(localized: "Delete API key?"),
            message: String(localized: "\"\(name)\" stops working immediately. Apps and scripts using it lose access."),
            confirmLabel: String(localized: "Delete"), destructive: true
        ) { Task { await delete(key) } }
    }

    private func delete(_ key: APIKey) async {
        deleting = true
        defer { deleting = false }
        do {
            try await session.api.apiKeys.delete(key.id)
            keys.removeAll { $0.id == key.id }
        } catch let failure as IPv64Error where failure.isConflict {
            var detail = String(localized: "This key is used by this app and cannot be deleted.")
            if case .api(let problem) = failure, let text = problem.detail.nonBlank { detail = text }
            error = ErrorText(title: String(localized: "Key in use"), message: detail)
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
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
