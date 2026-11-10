import SwiftUI
import IPv64

/// Node check create / edit (spec 02 B7): form only, Save and Delete in the toolbar.
struct NodeCheckEditView: View {
    let nodeId: String
    /// `nil` = new node healthcheck.
    let token: String?

    @Environment(ConnectedNodes.self) private var nodes
    @Environment(Router.self) private var router

    @State private var f = NodeCheckFormState()
    @State private var loading = false
    @State private var busyText: LocalizedStringKey?
    @State private var inlineError: String?
    @State private var error: ErrorText?
    @State private var popAfterError = false
    @State private var confirm: ConfirmRequest?
    @State private var advancedOpen = false
    @State private var notificationsOpen = false

    private var client: Node64? { nodes.client(for: nodeId) }

    var body: some View {
        Group {
            if client == nil {
                Text("This node is not connected.").foregroundStyle(Color.ipv64Red).padding()
            } else if loading {
                LoadingView()
            } else {
                form
            }
        }
        .navigationTitle(token == nil ? "New node healthcheck" : "Edit node healthcheck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if client != nil {
                if f.base?.token != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Delete", systemImage: "trash", role: .destructive) { askDelete() }
                            .disabled(busyText != nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") { Task { await save() } }
                        .disabled(busyText != nil || loading)
                }
            }
        }
        .task { await load() }
        .loadingOverlay(busyText != nil, text: busyText ?? "Loading...")
        .errorAlert($error)
        .onChange(of: error == nil) { _, isNil in
            if isNil && popAfterError { popAfterError = false; router.pop() }
        }
        .confirmDialog($confirm)
    }

    // MARK: Form

    private var form: some View {
        Form {
            Section("Check") {
                HcField(label: "Name", text: $f.name)
                Picker("Type", selection: $f.type) {
                    Text("Choose…").tag(Node64.CheckType?.none)
                    ForEach(nodeCheckTypes, id: \.self) { Text(verbatim: $0.label).tag(Optional($0)) }
                }
                .disabled(f.editing)
                HcField(label: "Target", text: $f.target, kind: .url,
                        footer: f.type == .push ? "Not needed for push checks." : "URL, host or domain, depending on the type.")
                if f.type == .keyword { HcField(label: "Keyword", text: $f.keyword) }
                if f.type == .tcp || f.type == .port || f.type == .cert {
                    HcField(label: "Port", text: $f.port, kind: .number)
                }
                if f.type == .dns {
                    Picker("Record type", selection: $f.recordType) {
                        ForEach(dnsRecordTypes, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
                    }
                }
            }
            Section {
                DisclosureGroup("Advanced", isExpanded: $advancedOpen) {
                    HcField(label: "Interval (seconds)", text: $f.interval, kind: .number)
                    HcField(label: "Retry interval (seconds)", text: $f.retryInterval, kind: .number)
                    HcField(label: "Retries (0-10)", text: $f.retries, kind: .number)
                    HcField(label: "Timeout (seconds)", text: $f.timeout, kind: .decimal)
                    HcField(label: "Connect timeout (seconds)", text: $f.connectTimeout, kind: .decimal)
                    HcField(label: "Stabilize (1-20)", text: $f.stabilize, kind: .number,
                            footer: "Measurements until the state changes")
                    HcToggle(label: "Invert result", isOn: $f.invert)
                    Picker("IP mode", selection: $f.ipMode) {
                        ForEach(ipModes, id: \.self) { Text(verbatim: $0?.rawValue ?? String(localized: "Default")).tag($0) }
                    }
                }
            }
            Section {
                DisclosureGroup("Notifications & organisation", isExpanded: $notificationsOpen) {
                    HcToggle(label: "Notify when down", isOn: $f.notifyDown)
                    HcToggle(label: "Notify when back up", isOn: $f.notifyUp)
                    HcToggle(label: "Notify when degraded", isOn: $f.notifyDegraded, footer: "Also notify on partial failure")
                    HcToggle(label: "Critical", isOn: $f.critical, footer: "Ignores quiet hours")
                    HcRepeatPicker(minutes: $f.repeatMinutes, allowsDefault: f.base?.repeatMinutes == nil)
                    HcField(label: "Tags", text: $f.tags, footer: "Comma-separated")
                    HcField(label: "Group", text: $f.group)
                    HcField(label: "Description", text: $f.description, multiline: true)
                    if !f.editing { HcToggle(label: "Start paused", isOn: $f.startPaused) }
                }
            }
            if let inlineError {
                Section { Text(verbatim: inlineError).foregroundStyle(Color.ipv64Red) }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var ipModes: [Node64.CheckIPMode?] {
        [nil, .auto, .ipv4, .ipv6, .both].filter { !($0 == nil && f.base?.ipMode != nil) }
    }

    // MARK: Actions

    private func load() async {
        guard let token, f.base == nil, let client else { return }
        loading = true
        defer { loading = false }
        do {
            f.apply(try await client.hc.checks.get(token))
        } catch is CancellationError {
        } catch {
            popAfterError = true
            self.error = ErrorText.node(error)
        }
    }

    private func save() async {
        if token != nil && f.base == nil { return }
        inlineError = nil
        if let message = f.validate() {
            inlineError = message
            error = ErrorText(title: String(localized: "Check your input"), message: message)
            return
        }
        guard let client, let input = f.input() else { return }
        busyText = "Saving..."
        defer { busyText = nil }
        do {
            if let token { try await client.hc.checks.update(token, input) } else { try await client.hc.checks.create(input) }
            router.reload()
            router.pop()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText.node(error)
        }
    }

    private func askDelete() {
        confirm = ConfirmRequest(
            title: String(localized: "Delete healthcheck?"),
            message: String(localized: "\"\(f.name)\" will be removed from the node."),
            confirmLabel: String(localized: "Delete"), destructive: true
        ) { Task { await delete() } }
    }

    private func delete() async {
        guard let token, let client else { return }
        busyText = "Deleting..."
        defer { busyText = nil }
        do {
            try await client.hc.checks.delete(token)
            router.reload()
            router.popToRoot()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText.node(error)
        }
    }
}
