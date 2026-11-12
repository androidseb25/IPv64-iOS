import SwiftUI
import IPv64

/// New / edit healthcheck, shown as a sheet: essentials on top, collapsible "Advanced" and "Notifications & organisation".
struct HealthcheckFormView: View {
    /// `nil` = new healthcheck.
    let token: String?
    /// Called after the check was created or changed.
    let onSaved: () -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var f = HealthcheckFormState()
    @State private var initial = HealthcheckFormState()
    @State private var account: HC2Account?
    @State private var channels: [HC2Channel] = []
    @State private var channelTypes: [HC2ChannelType]?
    @State private var nodes: [HC2Node] = []
    @State private var detail: HC2CheckDetail?
    @State private var loading = true
    @State private var isSaving = false
    @State private var error: ErrorText?
    @State private var dismissAfterError = false
    @State private var advancedOpen = false
    @State private var notificationsOpen = false
    @State private var pushUrl: PushUrlItem?

    private var editing: Bool { token != nil }
    private var maxLocations: Int? { account?.locationsPerCheck.flatMap { $0 > 0 ? $0 : nil } }
    private var issue: (message: String, section: HealthcheckFormState.FormSection)? {
        f.validate(maxLocations: maxLocations)
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                } else {
                    form
                }
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
        .sheet(item: $pushUrl) { item in
            PushUrlSheet(url: item.url) { dismiss() }
        }
    }

    private var form: some View {
        Form {
            HealthcheckCheckSection(f: $f, editing: editing)
            HealthcheckExecutionSection(f: $f, editing: editing, nodes: nodes, account: account, detail: detail)
            HealthcheckAdvancedSection(f: $f, expanded: $advancedOpen, editing: editing, detail: detail)
            HealthcheckNotificationsSection(f: $f, expanded: $notificationsOpen, editing: editing, detail: detail,
                                            channels: channels, channelTypes: channelTypes)
            if let issue, f != initial {
                Section {
                    Text(verbatim: issue.message).foregroundStyle(.red)
                    if issue.section == .advanced && !advancedOpen {
                        Button("Show Advanced") { advancedOpen = true }
                    } else if issue.section == .notifications && !notificationsOpen {
                        Button("Show Notifications & organisation") { notificationsOpen = true }
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(isSaving)
    }

    // MARK: Loading

    private func load() async {
        let api = session.api
        do {
            let acc = try await ipv64Retrying { try await api.hc2.account() }
            let list = try await ipv64Retrying { try await api.hc2.channels.list() }
            channelTypes = try? await ipv64Retrying { try await api.hc2.channels.types() }
            var state = HealthcheckFormState()
            if let token {
                let loaded = try await ipv64Retrying { try await api.hc2.checks.get(token) }
                detail = loaded
                state.apply(loaded, knownChannelIds: Set(list.map(\.id)))
            } else if let code = acc.locations?.first?.code {
                state.locations = [code]
            }
            if (acc.nodes?.total ?? 1) > 0 || state.execSel != .online {
                nodes = (try? await ipv64Retrying { try await api.hc2.nodes.list() }) ?? []
            }
            account = acc
            channels = list
            f = state
            initial = state
            loading = false
        } catch is CancellationError {
        } catch {
            dismissAfterError = true
            self.error = ErrorText(error)
        }
    }

    // MARK: Saving

    private func save() async {
        guard issue == nil else { return }
        isSaving = true
        defer { isSaving = false }
        let api = session.api
        do {
            if let old = detail, let token {
                try await saveEdit(token: token, old: old)
            } else {
                let input = f.createInput()
                let created = try await ipv64Retrying { try await api.hc2.checks.create(input) }
                onSaved()
                if f.type == .push, let url = created.push?.url?.nonBlank ?? created.push?.hubURL?.nonBlank {
                    pushUrl = PushUrlItem(url: url)
                } else {
                    dismiss()
                }
            }
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func saveEdit(token: String, old: HC2CheckDetail) async throws {
        let api = session.api
        let moveNeeded = f.moveNeeded(old: old)
        let (input, changed) = f.updateInput(old: old, moveNeeded: moveNeeded)
        var current = old
        if changed {
            current = try await ipv64Retrying { try await api.hc2.checks.update(token, input) }
            detail = current
            f.iniPs = f.ps
            f.iniPs.basicPassword = ""
            f.ps.basicPassword = ""
            onSaved()
        }
        guard moveNeeded else {
            dismiss()
            return
        }
        let fields = executionFields(f.execution, nodeId: f.nodeId, locations: f.locations)
        switch try await runHealthcheckMove(api: api, token: token, fields: fields) {
        case .applied:
            if f.policyApplies && f.policy != current.policy, let policy = f.policy {
                var policyOnly = HC2CheckInput(name: f.name.hcTrimmed, type: current.type ?? f.type)
                policyOnly.policy = policy
                _ = try await ipv64Retrying { try await api.hc2.checks.update(token, policyOnly) }
            }
            onSaved()
            dismiss()
        case .failed(let message):
            error = ErrorText(
                title: String(localized: "Execution not changed"),
                message: String(localized: "The test run failed, so the check keeps its previous settings. Other changes were saved.") + "\n\n" + message)
        case .timedOut:
            dismissAfterError = true
            error = ErrorText(
                title: String(localized: "Change pending"),
                message: String(localized: "The test run did not finish within 60 seconds. Check the healthcheck details later to see whether the change was applied."))
        }
    }
}

struct PushUrlItem: Identifiable {
    let id = UUID()
    let url: String
}

/// Shown after creating a push check. Never swipe-dismissable; closes only via its button.
struct PushUrlSheet: View {
    let url: String
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(verbatim: url).font(.callout.monospaced()).textSelection(.enabled)
                    Button("Copy", systemImage: "doc.on.doc") { Clipboard.copy(url, sensitive: true) }
                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                } footer: {
                    Text("Call this URL from your job or service to report that it is alive.")
                }
            }
            .navigationTitle("Push URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        onDone()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
