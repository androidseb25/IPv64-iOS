import SwiftUI
import IPv64

/// New / edit Monitor64 host with its accesses, shown as a sheet (same look as `HealthcheckFormView`).
struct Monitor64HostFormView: View {
    let nodeId: String
    /// `nil` = new host.
    let uid: String?
    let onSaved: () -> Void

    @Environment(ConnectedNodes.self) private var nodes
    @Environment(\.dismiss) private var dismiss

    @State private var loaded: Node64.Monitor64Host?
    @State private var name = ""
    @State private var address = ""
    @State private var kind = Node64.Monitor64HostKind.unspecified
    @State private var group = ""
    @State private var tags = ""
    @State private var interval = ""
    @State private var notes = ""
    @State private var paused = false
    /// Access of a new host.
    @State private var draft = Monitor64AccessDraft()
    @State private var accesses: [Node64.Monitor64AccessState] = []
    @State private var test = Monitor64AccessTestState()
    @State private var accessEdit: Monitor64AccessDraft?
    @State private var loading: Bool
    @State private var isSaving = false
    @State private var error: ErrorText?
    @State private var dismissAfterError = false

    init(nodeId: String, uid: String?, onSaved: @escaping () -> Void) {
        self.nodeId = nodeId
        self.uid = uid
        self.onSaved = onSaved
        _loading = State(initialValue: uid != nil)
    }

    private var editing: Bool { uid != nil }
    private var client: Node64? { nodes.client(for: nodeId) }

    private var intervalSeconds: Int? { interval.nonBlank.flatMap { Int($0.hcTrimmed) } }

    private var issue: String? {
        if name.nonBlank == nil { return String(localized: "Please enter a name.") }
        if name.hcTrimmed.count > 100 { return String(localized: "The name can have at most 100 characters.") }
        if address.nonBlank == nil { return String(localized: "Please enter an address.") }
        if interval.nonBlank != nil, !(intervalSeconds.map { (30...900).contains($0) } ?? false) {
            return String(localized: "Interval must be 30 to 900 seconds.")
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading { ProgressView() } else { form }
            }
            .navigationTitle(editing ? "Edit Monitor64 host" : "New Monitor64 host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(editing ? "Save" : "Create") { Task { await save() } }
                            .disabled(loading || issue != nil)
                    }
                }
            }
            .navigationDestination(item: $accessEdit) { edit in
                Monitor64AccessEditView(nodeId: nodeId, hostUID: uid ?? "", address: address, draft: edit) {
                    Task { await reloadAccesses() }
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isSaving)
        .task { await load() }
        .errorAlert($error)
        .onChange(of: error == nil) { _, isNil in
            if isNil && dismissAfterError { dismissAfterError = false; dismiss() }
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Address", text: $address)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                if editing {
                    LabeledContent("Kind") { Text(verbatim: kind.label) }
                } else {
                    Picker("Kind", selection: $kind) {
                        ForEach(monitor64HostKinds, id: \.self) { Text(verbatim: $0.label).tag($0) }
                    }
                }
            } footer: {
                HcFooter(hint: "Hostname, IPv4 or IPv6", error: touched ? issue : nil)
            }
            Section {
                TextField("Group", text: $group)
                TextField("Tags, comma-separated", text: $tags)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                HcFieldRow(label: "Interval", text: $interval, kind: .number, prompt: "Default", unit: "s")
                HcMultilineField(placeholder: "Notes", text: $notes)
                Toggle("Paused", isOn: $paused)
            } footer: {
                Text(editing ? "Interval: 30 to 900 seconds, empty = current node default"
                             : "Interval: 30 to 900 seconds, empty = node default")
            }
            if editing { accessesSection } else { newAccessSection }
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(isSaving)
    }

    /// Validation messages only show once something was typed.
    private var touched: Bool { !name.isEmpty || !address.isEmpty || !interval.isEmpty }

    private var accessesSection: some View {
        Section("Accesses") {
            ForEach(accesses, id: \.uid) { a in
                Button {
                    accessEdit = Monitor64AccessDraft(a)
                } label: {
                    HcDetailRow(
                        title: (a.name?.nonBlank ?? a.type?.rawValue ?? "").m64Text,
                        subtitle: [a.type?.rawValue, a.enabled == false ? String(localized: "Off") : nil,
                                   a.error?.nonBlank?.m64Text].compactMap { $0 }
                    ) { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
                }
                .tint(.primary)
            }
            Button("Add access", systemImage: "plus") { accessEdit = Monitor64AccessDraft(uid: nil, type: .agent) }
        }
    }

    private var newAccessSection: some View {
        Section {
            Picker("Access", selection: $draft.type) {
                Text("None (add later)").tag(Node64.Monitor64AccessType?.none)
                ForEach(monitor64AccessTypes, id: \.self) { Text(verbatim: $0.rawValue).tag(Optional($0)) }
            }
            if draft.type != nil {
                Monitor64AccessFields(draft: $draft, address: address, test: $test, client: client) { error = $0 }
            }
        } header: {
            Text("Access")
        }
    }

    // MARK: Loading and saving

    private func load() async {
        guard let uid, loading else { return }
        guard let client else {
            dismissAfterError = true
            error = ErrorText(title: String(localized: "Node not reachable"),
                              message: String(localized: "No local access stored for this node."))
            return
        }
        do {
            let detail = try await client.monitor64.hosts.get(uid)
            guard let h = detail.host else {
                dismissAfterError = true
                error = ErrorText(title: String(localized: "Host not found"),
                                  message: String(localized: "The node returned no data for this host."))
                return
            }
            loaded = h
            accesses = detail.accesses ?? []
            name = h.name ?? ""
            address = h.address ?? ""
            kind = h.kind ?? .unspecified
            group = h.group ?? ""
            tags = (h.tags ?? []).joined(separator: ", ")
            notes = h.notes ?? ""
            interval = h.intervalSec.flatMap { $0 > 0 ? String($0) : nil } ?? ""
            paused = h.paused == true
            loading = false
        } catch is CancellationError {
        } catch {
            dismissAfterError = true
            self.error = hostError(error)
        }
    }

    private func reloadAccesses() async {
        guard let uid, let client else { return }
        if let detail = try? await client.monitor64.hosts.get(uid) { accesses = detail.accesses ?? [] }
        onSaved()
    }

    private func save() async {
        guard issue == nil, let client else { return }
        isSaving = true
        defer { isSaving = false }
        let tagList = hcParseTags(tags)
        do {
            if let uid {
                guard let loaded else { return }
                // Empty interval: the API only knows "unchanged" on edit, so use the node default.
                let seconds: Int?
                if let given = intervalSeconds { seconds = given } else { seconds = try? await client.monitor64.settings().interval }
                let input = Node64.Monitor64HostInput(
                    name: name.hcTrimmed, address: address.hcTrimmed, kind: loaded.kind, group: group.hcTrimmed, tags: tagList,
                    intervalSec: seconds, notes: notes.hcTrimmed, paused: paused, agentAutoupdate: loaded.agentAutoupdate)
                _ = try await client.monitor64.hosts.update(uid, input)
            } else {
                // Services only after a successful test; the default ones are adopted right away.
                let tested = draft.type != nil && test.result?.ok == true ? test.result?.services : nil
                let create = Node64.Monitor64HostCreate(
                    name: name.hcTrimmed, address: address.hcTrimmed, kind: kind == .unspecified ? nil : kind,
                    group: group.nonBlank?.hcTrimmed, tags: tagList.isEmpty ? nil : tagList, intervalSec: intervalSeconds,
                    notes: notes.nonBlank?.hcTrimmed, paused: paused ? true : nil,
                    accesses: draft.input().map { [$0] },
                    services: tested.flatMap { $0.isEmpty ? nil : $0 },
                    adopt: tested.flatMap { list in
                        let keys = list.filter { $0.isDefault == true }.map(\.key)
                        return keys.isEmpty ? nil : keys
                    })
                _ = try await client.monitor64.hosts.create(create)
            }
            onSaved()
            dismiss()
        } catch is CancellationError {
        } catch {
            self.error = hostError(error)
        }
    }
}

/// Result of the connection test and the fingerprint waiting for confirmation.
struct Monitor64AccessTestState: Equatable {
    var result: Node64.Monitor64TestResult?
    var askFingerprint: String?
    var running = false
}

/// Fields of one access with the connection test and the fingerprint confirmation.
struct Monitor64AccessFields: View {
    @Binding var draft: Monitor64AccessDraft
    let address: String
    @Binding var test: Monitor64AccessTestState
    let client: Node64?
    let onError: (ErrorText) -> Void

    var body: some View {
        Group {
            HcFieldRow(label: "Port", text: $draft.port, kind: .number, prompt: "Default")
            HcFieldRow(label: "User", text: $draft.user, prompt: "")
            HcFieldRow(label: "URL", text: $draft.url, kind: .url, prompt: "")
            HcFieldRow(label: "Token ID", text: $draft.tokenId, prompt: "")
            HcFieldRow(label: "Secret", text: $draft.secret, kind: .secure, prompt: "Password, token or key")
            if draft.uid != nil { Toggle("Enabled", isOn: $draft.enabled) }
            Button {
                Task { await runTest() }
            } label: {
                HStack {
                    Text("Test connection")
                    Spacer()
                    if test.running { ProgressView() }
                }
            }
            .disabled(test.running)
            if let r = test.result {
                Text(verbatim: resultText(r))
                    .font(.footnote)
                    .foregroundStyle(r.ok == true ? Color.secondary : Color.red)
            }
        }
        // A changed target invalidates the test and a confirmed fingerprint.
        .onChange(of: draft.targetKey) {
            test.result = nil
            draft.fingerprint = nil
        }
        .onChange(of: address) {
            test.result = nil
            draft.fingerprint = nil
        }
        .alert("Trust this fingerprint?", isPresented: Binding(
            get: { test.askFingerprint != nil }, set: { if !$0 { test.askFingerprint = nil } }),
               presenting: test.askFingerprint) { fingerprint in
            Button("Trust and test again") {
                draft.fingerprint = fingerprint
                Task { await runTest() }
            }
            Button("Cancel", role: .cancel) {}
        } message: { fingerprint in
            Text(verbatim: fingerprint)
        }
    }

    private func resultText(_ r: Node64.Monitor64TestResult) -> String {
        if r.ok == true {
            return [String(localized: "Connection OK"), r.summary?.nonBlank,
                    String(localized: "\(r.services?.count ?? 0) services found"), r.warning?.nonBlank]
                .compactMap { $0 }.joined(separator: " · ").m64Text
        }
        return r.error?.nonBlank?.m64Text ?? String(localized: "Connection failed.")
    }

    private func runTest() async {
        guard let client, let access = draft.input() else { return }
        guard address.nonBlank != nil else {
            onError(ErrorText(title: String(localized: "Check your input"), message: String(localized: "Please enter an address.")))
            return
        }
        test.running = true
        defer { test.running = false }
        do {
            // A saved access: empty fields (also the secret) count as saved.
            let result = if let uid = draft.uid {
                try await client.monitor64.access.test(uid, changes: access)
            } else {
                try await client.monitor64.test(Node64.Monitor64TestInput(address: address.hcTrimmed, access: access))
            }
            test.result = result
            if result.needConfirm == true { test.askFingerprint = result.fingerprint }
        } catch is CancellationError {
        } catch {
            onError(hostError(error))
        }
    }
}

/// Pushed in the host form: edit or add one access of a saved host.
struct Monitor64AccessEditView: View {
    let nodeId: String
    let hostUID: String
    let address: String
    let onSaved: () -> Void

    @Environment(ConnectedNodes.self) private var nodes
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Monitor64AccessDraft
    @State private var test = Monitor64AccessTestState()
    @State private var isSaving = false
    @State private var confirmDelete = false
    @State private var error: ErrorText?

    init(nodeId: String, hostUID: String, address: String, draft: Monitor64AccessDraft, onSaved: @escaping () -> Void) {
        self.nodeId = nodeId
        self.hostUID = hostUID
        self.address = address
        self.onSaved = onSaved
        _draft = State(initialValue: draft)
    }

    private var client: Node64? { nodes.client(for: nodeId) }

    var body: some View {
        Form {
            Section {
                if draft.uid == nil {
                    Picker("Access", selection: $draft.type) {
                        ForEach(monitor64AccessTypes, id: \.self) { Text(verbatim: $0.rawValue).tag(Optional($0)) }
                    }
                } else {
                    LabeledContent("Access") { Text(verbatim: draft.type?.rawValue ?? "") }
                }
                Monitor64AccessFields(draft: $draft, address: address, test: $test, client: client) { error = $0 }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(isSaving)
        .navigationTitle(draft.uid == nil ? "New access" : "Edit access")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if draft.uid != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        DestructiveMenuButton("Delete access", systemImage: "trash") { confirmDelete = true }
                    } label: {
                        Label("More actions", systemImage: "ellipsis")
                    }
                    .disabled(isSaving)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") { Task { await save() } }.disabled(draft.type == nil)
                }
            }
        }
        .alert("Delete access?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The host can no longer be queried through this access.")
        }
        .errorAlert($error)
    }

    private func save() async {
        guard let client, let input = draft.input() else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            if let uid = draft.uid {
                _ = try await client.monitor64.access.update(uid, input)
            } else {
                _ = try await client.monitor64.hosts.createAccess(host: hostUID, input)
            }
            onSaved()
            dismiss()
        } catch is CancellationError {
        } catch {
            self.error = hostError(error)
        }
    }

    private func delete() async {
        guard let client, let uid = draft.uid else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await client.monitor64.access.delete(uid)
            onSaved()
            dismiss()
        } catch is CancellationError {
        } catch {
            self.error = hostError(error)
        }
    }
}
