import SwiftUI
import IPv64

/// "New API key" sheet (spec 04 §8). Calls `onCreated` with the created key (incl. one-time token).
struct ApiKeyCreateSheet: View {
    let onCreated: (APIKeyCreated) -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var validity = ApiKeyText.defaultValidity
    @State private var isBusy = false
    @State private var error: ErrorText?

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        SheetScaffold("New API key", confirmLabel: "Create", confirmEnabled: !trimmed.isEmpty && !isBusy,
                      isBusy: isBusy, detents: [.medium, .large], onConfirm: { Task { await create() } }) {
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
    }

    private func create() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let created = try await session.api.apiKeys.create(name: trimmed, expiresIn: validity)
            onCreated(created)
            dismiss()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error, context: .create)
        }
    }
}

/// Shows a new secret exactly once (spec 04 §8 SecretOnceDialog); not dismissible except via "Done".
struct SecretOnceSheet: View {
    let key: APIKeyCreated
    let onDone: () -> Void

    @State private var revealed = false

    var body: some View {
        SheetScaffold("New API key", confirmLabel: "Done", dismissible: false, detents: [.medium], onConfirm: onDone) {
            Section {
                Label("Copy the key now and store it securely. It is shown only once and cannot be retrieved later.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color.ipv64Orange)
            }
            Section {
                InfoRow("Key", value: key.token, copyable: true, sensitive: true, monospaced: true)
            }
        }
        .privacyProtected()
    }
}
