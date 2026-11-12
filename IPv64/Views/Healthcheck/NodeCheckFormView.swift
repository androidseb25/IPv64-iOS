import SwiftUI
import IPv64

/// New / edit node healthcheck, shown as a sheet (same look as `HealthcheckFormView`).
struct NodeCheckFormView: View {
    let nodeId: String
    /// `nil` = new healthcheck.
    let token: String?
    /// Called after the check was created or changed.
    let onSaved: () -> Void

    @Environment(ConnectedNodes.self) private var nodes
    @Environment(\.dismiss) private var dismiss

    @State private var f = NodeCheckFormState()
    @State private var initial = NodeCheckFormState()
    @State private var loading: Bool
    @State private var isSaving = false
    @State private var error: ErrorText?
    @State private var dismissAfterError = false
    @State private var advancedOpen = false
    @State private var notificationsOpen = false

    init(nodeId: String, token: String?, onSaved: @escaping () -> Void) {
        self.nodeId = nodeId
        self.token = token
        self.onSaved = onSaved
        _loading = State(initialValue: token != nil)
    }

    private var editing: Bool { token != nil }
    private var client: Node64? { nodes.client(for: nodeId) }
    private var issue: String? { f.validate() }

    var body: some View {
        NavigationStack {
            Group {
                if loading { ProgressView() } else { form }
            }
            .navigationTitle(editing ? "Edit Healthcheck" : "New Healthcheck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
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
                if editing {
                    LabeledContent("Type") {
                        HStack(spacing: 6) {
                            Image(systemName: f.type.hc2.symbol).foregroundStyle(.tint)
                            Text(f.type.label)
                        }
                    }
                } else {
                    Picker("Type", selection: $f.type) {
                        ForEach(nodeCheckTypes, id: \.self) { Label($0.label, systemImage: $0.hc2.symbol).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                }
                TextField("Name", text: $f.name)
                if f.type != .push {
                    TextField(f.type.hc2.targetHint, text: $f.target)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            } footer: {
                HcFooter(hint: f.type == .push && !editing ? "A push URL is created with the check." : nil,
                         error: f != initial ? issue : nil)
            }
            essential
            HcCollapsibleSection(
                title: "Advanced", isExpanded: $advancedOpen,
                hint: editing ? "Clearing a field keeps the current value; it cannot be reset to the default here."
                              : "Empty fields use the server default."
            ) {
                HcDurationPicker(label: "Interval", value: $f.intervalValue, unit: $f.intervalUnit,
                                 presets: [20, 30, 60, 120, 300, 600, 900, 1800, 3600],
                                 allowsDefault: !(editing && f.base?.intervalSeconds != nil))
                HcDurationPicker(label: "Retry interval", value: $f.retryValue, unit: $f.retryUnit,
                                 presets: [5, 10, 30, 60, 120, 300],
                                 allowsDefault: !(editing && f.base?.retryIntervalSeconds != nil))
                HcStepperRow(label: "Retries", text: $f.retries, range: 0...10)
                HcFieldRow(label: "Timeout", text: $f.timeout, kind: .decimal, prompt: "Default", unit: "s")
                HcFieldRow(label: "Connect timeout", text: $f.connectTimeout, kind: .decimal, prompt: "Default", unit: "s")
                HcStepperRow(label: "Stabilize", text: $f.stabilize, range: 1...20)
                Toggle("Invert result", isOn: $f.invert)
                Picker("IP mode", selection: $f.ipMode) {
                    ForEach(ipModes, id: \.self) { Text(verbatim: $0?.rawValue ?? String(localized: "Default")).tag($0) }
                }
            }
            HcCollapsibleSection(
                title: "Notifications & organisation", isExpanded: $notificationsOpen,
                hint: "Degraded also notifies on partial failure. Critical ignores quiet hours."
            ) {
                Toggle("Notify when down", isOn: $f.notifyDown)
                Toggle("Notify when back up", isOn: $f.notifyUp)
                Toggle("Notify when degraded", isOn: $f.notifyDegraded)
                Toggle("Critical", isOn: $f.critical)
                HcRepeatPicker(minutes: $f.repeatMinutes, allowsDefault: !(editing && f.base?.repeatMinutes != nil))
                TextField("Tags, comma-separated", text: $f.tags)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Group", text: $f.group)
                HcMultilineField(placeholder: "Description", text: $f.description)
                if !editing { Toggle("Create paused", isOn: $f.createPaused) }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(isSaving)
    }

    private var ipModes: [Node64.CheckIPMode?] {
        [nil, .auto, .ipv4, .ipv6, .both].filter { !($0 == nil && editing && f.base?.ipMode != nil) }
    }

    /// Core parameters of the type in their own section.
    @ViewBuilder private var essential: some View {
        switch f.type {
        case .keyword:
            Section("Keyword") {
                TextField("Keyword", text: $f.keyword).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
        case .dns:
            Section("DNS") {
                Picker("Record type", selection: $f.recordType) {
                    ForEach(dnsRecordTypes, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
                }
            }
        case .tcp, .port, .cert:
            Section {
                HcFieldRow(label: "Port", text: $f.port, kind: .number, prompt: "443")
            } header: {
                Text("Port")
            } footer: {
                Text("Or use host:port as target")
            }
        default:
            EmptyView()
        }
    }

    // MARK: Loading and saving

    private func load() async {
        guard let token, loading else { return }
        guard let client else {
            dismissAfterError = true
            error = ErrorText(title: String(localized: "Node not reachable"),
                              message: String(localized: "No local access stored for this node."))
            return
        }
        do {
            var state = NodeCheckFormState()
            state.apply(try await client.hc.checks.get(token))
            f = state
            initial = state
            loading = false
        } catch is CancellationError {
        } catch {
            dismissAfterError = true
            self.error = .node(error)
        }
    }

    private func save() async {
        guard issue == nil, let client else { return }
        isSaving = true
        defer { isSaving = false }
        let input = f.input()
        do {
            if let token {
                try await client.hc.checks.update(token, input)
            } else {
                try await client.hc.checks.create(input)
            }
            onSaved()
            dismiss()
        } catch is CancellationError {
        } catch {
            self.error = .node(error)
        }
    }
}

/// First sheet of "+": where the new healthcheck runs.
struct HealthcheckTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// (nodeId, name) of the reachable nodes that offer checks.
    let nodes: [(id: String, name: String)]
    /// Nodes with Monitor64.
    let monitorNodes: [(id: String, name: String)]
    /// The caller presents the form after this sheet closed.
    let onChoose: (HealthcheckTarget) -> Void

    var body: some View {
        NavigationStack {
            List {
                choice(title: "Account healthcheck", subtitle: "Runs from ipv64.net locations", symbol: "cloud", target: .account)
                ForEach(nodes, id: \.id) { node in
                    choice(title: "On node \(node.name)", subtitle: "Runs locally on \(node.name)", symbol: "network",
                           target: .nodeCheck(node.id))
                }
                ForEach(monitorNodes, id: \.id) { node in
                    choice(title: "Monitor64 host on \(node.name)", subtitle: "Monitors a server or device from \(node.name)",
                           symbol: "server.rack", target: .monitor64Host(node.id))
                }
            }
            .navigationTitle("New Healthcheck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }

    private func choice(title: LocalizedStringKey, subtitle: LocalizedStringKey, symbol: String, target: HealthcheckTarget) -> some View {
        Button {
            onChoose(target)
            dismiss()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            } icon: { Image(systemName: symbol) }
        }
        .tint(.primary)
    }
}
