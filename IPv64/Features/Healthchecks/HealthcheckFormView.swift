import SwiftUI
import IPv64

/// New / edit healthcheck (spec 02 B4): essentials on top, collapsible "Advanced" and "Notifications & organisation".
struct HealthcheckFormView: View {
    /// `nil` = new healthcheck.
    let token: String?

    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    @State private var f = HealthcheckFormState()
    @State private var account: HC2Account?
    @State private var channels: [HC2Channel] = []
    @State private var channelTypes: [HC2ChannelType]?
    @State private var nodes: [HC2Node] = []
    @State private var detail: HC2CheckDetail?
    @State private var loading = true
    @State private var saving: String?
    @State private var error: ErrorText?
    @State private var popAfterError = false
    @State private var advancedOpen = false
    @State private var notificationsOpen = false
    @State private var pushUrl: PushUrlItem?

    private var editing: Bool { token != nil }

    var body: some View {
        Group {
            if loading {
                LoadingView()
            } else {
                Form {
                    HealthcheckCheckSection(f: $f, editing: editing, hasNodes: !nodes.isEmpty)
                    HealthcheckExecutionSection(f: $f, editing: editing, nodes: nodes, account: account, detail: detail)
                    HealthcheckAdvancedSection(f: $f, expanded: $advancedOpen, editing: editing, detail: detail)
                    HealthcheckNotificationsSection(f: $f, expanded: $notificationsOpen, editing: editing, detail: detail,
                                                    channels: channels, channelTypes: channelTypes)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle(editing ? "Edit Healthcheck" : "New Healthcheck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark") { Task { await save() } }
                    .disabled(loading || saving != nil)
            }
        }
        .task { await load() }
        .loadingOverlay(saving != nil, text: LocalizedStringKey(saving ?? ""))
        .errorAlert($error)
        .onChange(of: error == nil) { _, isNil in
            if isNil && popAfterError { popAfterError = false; router.pop() }
        }
        .sheet(item: $pushUrl) { item in
            PushUrlSheet(url: item.url) { router.reload(); router.pop() }
        }
    }

    // MARK: Loading

    private func load() async {
        do {
            let acc = try await ipv64Retrying { try await session.api.hc2.account() }
            let list = try await ipv64Retrying { try await session.api.hc2.channels.list() }
            channelTypes = try? await ipv64Retrying { try await session.api.hc2.channels.types() }
            var state = HealthcheckFormState()
            if let token {
                let loaded = try await ipv64Retrying { try await session.api.hc2.checks.get(token) }
                detail = loaded
                state.apply(loaded, knownChannelIds: Set(list.map(\.id)))
            } else if let code = acc.locations?.first?.code {
                state.locations = [code]
            }
            if (acc.nodes?.total ?? 1) > 0 || state.execSel != .online {
                nodes = (try? await ipv64Retrying { try await session.api.hc2.nodes.list() }) ?? []
            }
            account = acc
            channels = list
            f = state
            loading = false
        } catch is CancellationError {
        } catch {
            popAfterError = true
            self.error = ErrorText(error)
        }
    }

    // MARK: Saving

    private func save() async {
        let maxLocations = account?.locationsPerCheck.flatMap { $0 > 0 ? $0 : nil }
        if let issue = f.validate(maxLocations: maxLocations) {
            switch issue.section {
            case .advanced: advancedOpen = true
            case .notifications: notificationsOpen = true
            case .main: break
            }
            error = ErrorText(title: String(localized: "Invalid input"), message: issue.message)
            return
        }
        saving = String(localized: "Saving healthcheck...")
        defer { saving = nil }
        do {
            if let old = detail, let token {
                try await saveEdit(token: token, old: old)
            } else {
                let created = try await ipv64Retrying { try await session.api.hc2.checks.create(f.createInput()) }
                if f.type == .push, let url = (created.push?.url?.nonBlank ?? created.push?.hubURL?.nonBlank) {
                    pushUrl = PushUrlItem(url: url)
                } else {
                    router.reload()
                    router.pop()
                }
            }
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error, context: .update)
        }
    }

    private func saveEdit(token: String, old: HC2CheckDetail) async throws {
        let moveNeeded = f.moveNeeded(old: old)
        let (input, changed) = f.updateInput(old: old, moveNeeded: moveNeeded)
        var current = old
        if changed {
            current = try await ipv64Retrying { try await session.api.hc2.checks.update(token, input) }
            detail = current
            f.iniPs = f.ps
            f.iniPs.basicPassword = ""
            f.ps.basicPassword = ""
            router.reload()
        }
        guard moveNeeded else {
            router.reload()
            router.pop()
            return
        }
        saving = String(localized: "Testing the new setup…")
        let fields = executionFields(f.execution, nodeId: f.nodeId, locations: f.locations)
        switch try await runHealthcheckMove(api: session.api, token: token, fields: fields) {
        case .applied:
            router.reload()
            if f.policyApplies && f.policy != current.policy, let policy = f.policy {
                saving = String(localized: "Saving healthcheck...")
                var policyOnly = HC2CheckInput(name: f.name.hcTrimmed, type: current.type ?? f.type)
                policyOnly.policy = policy
                _ = try await ipv64Retrying { try await session.api.hc2.checks.update(token, policyOnly) }
            }
            router.pop()
        case .failed(let message):
            error = ErrorText(
                title: String(localized: "Execution not changed"),
                message: String(localized: "The test run failed, so the check keeps its previous settings. Other changes were saved.") + "\n\n" + message)
        case .timedOut:
            popAfterError = true
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

/// Shown after creating a push check. Never swipe-dismissable; closes only via its buttons.
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
                } footer: {
                    Text("Call this URL from your job or service to report that it is alive.")
                }
            }
            .navigationTitle("Push URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
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
