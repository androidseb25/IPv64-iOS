import SwiftUI
import IPv64

/// "Edit node" (cloud nodes): name, location, remote management. Sends only changed values.
struct NodeEditSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    let nodeId: String
    let info: NodeInfo
    let onSaved: (HC2Node) -> Void

    @State private var name: String
    @State private var location: String
    @State private var remote: String
    @State private var inlineError: String?
    @State private var isSaving = false

    init(nodeId: String, info: NodeInfo, onSaved: @escaping (HC2Node) -> Void) {
        self.nodeId = nodeId
        self.info = info
        self.onSaved = onSaved
        _name = State(initialValue: info.name ?? "")
        _location = State(initialValue: info.location ?? "")
        _remote = State(initialValue: info.remote ?? "full")
    }

    private var newName: String { name.trimmingCharacters(in: .whitespaces) }
    private var newLocation: String { location.trimmingCharacters(in: .whitespaces) }

    private var changed: Bool {
        newName != (info.name ?? "") || newLocation != (info.location ?? "") || remote != (info.remote ?? "full")
    }

    var body: some View {
        DynDNSSheet(title: "Edit node", confirmLabel: "Save", confirmEnabled: changed && newName.nonBlank != nil,
                    isBusy: isSaving, onConfirm: { Task { await save() } }) {
            Section("Node") {
                TextField("Name", text: $name)
                TextField("Location", text: $location)
            }
            .disabled(isSaving)
            Section {
                Picker("Remote management", selection: $remote) {
                    Text("Full").tag("full")
                    Text("Read only").tag("read")
                    Text("Off").tag("off")
                }
            } footer: {
                Text(NodesLogic.remoteDescription(remote))
            }
            .disabled(isSaving)
            if let inlineError {
                Section { Text(inlineError).font(.footnote).foregroundStyle(.red) }
            }
        }
        .presentationDetents([.large])
    }

    private func save() async {
        let api = session.api
        let name = newName != (info.name ?? "") ? newName : nil
        let location = newLocation != (info.location ?? "") ? newLocation : nil
        let remote = remote != (info.remote ?? "full") ? HC2RemoteManagement(rawValue: remote) : nil
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await ipv64Retrying {
                try await api.hc2.nodes.update(nodeId, name: name, location: location, remoteManagement: remote)
            }
            onSaved(updated)
            dismiss()
        } catch is CancellationError {
        } catch {
            inlineError = ErrorText(error).message.nonBlank ?? error.localizedDescription
        }
    }
}

/// "Resolve conflict": conflict number and side; the detail then asks for confirmation.
struct ResolveConflictSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: (NodeCommand) -> Void

    @State private var number = ""
    @State private var keep = HC2ConflictResolution.server

    var body: some View {
        DynDNSSheet(title: "Resolve conflict",
                    subtitle: String(localized: "Enter the conflict number shown on the node and choose which version to keep."),
                    confirmLabel: "Continue", confirmEnabled: Int(number) != nil, onConfirm: {
            guard let id = Int(number) else { return }
            onContinue(NodeCommand(name: .resolveConflict, args: HC2CommandArguments(id: id, keep: keep)))
            dismiss()
        }) {
            Section {
                TextField("Conflict number", text: $number)
                    .keyboardType(.numberPad)
                    .onChange(of: number) { _, new in
                        let digits = new.filter(\.isNumber)
                        if digits != new { number = digits }
                    }
                Picker("Keep", selection: $keep) {
                    Text("Server version (ipv64.net)").tag(HC2ConflictResolution.server)
                    Text("Local version (node)").tag(HC2ConflictResolution.local)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// "Unlink node?" with a typed confirmation and the keep-checks switch.
struct NodeUnlinkSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    let nodeId: String
    let name: String
    let onResult: (HC2NodeUnlinkResult) -> Void

    @State private var keepChecks = true
    @State private var typed = ""
    @State private var inlineError: String?
    @State private var isUnlinking = false

    private var phrase: String { name.trimmingCharacters(in: .whitespaces).nonBlank ?? "unlink" }

    var body: some View {
        DynDNSSheet(title: "Unlink node?",
                    subtitle: String(localized: "The access token of \"\(name)\" is revoked. The node keeps running standalone but no longer syncs with ipv64.net. This cannot be undone."),
                    confirmLabel: "Unlink", confirmEnabled: typed.trimmingCharacters(in: .whitespaces) == phrase,
                    isBusy: isUnlinking, onConfirm: { Task { await unlink() } }) {
            Section {
                Toggle("Keep checks as online checks", isOn: $keepChecks)
            } footer: {
                Text(keepChecks ? "Checks with a public target continue as online checks."
                     : "The checks of this node are not continued and will be deleted.")
            }
            .disabled(isUnlinking)
            Section {
                TextField(phrase, text: $typed).textInputAutocapitalization(.never).autocorrectionDisabled()
            } footer: {
                Text("Type \"\(phrase)\" to confirm.")
            }
            .disabled(isUnlinking)
            if let inlineError {
                Section { Text(inlineError).font(.footnote).foregroundStyle(.red) }
            }
        }
        .presentationDetents([.large])
    }

    private func unlink() async {
        let api = session.api
        isUnlinking = true
        defer { isUnlinking = false }
        do {
            let result = try await ipv64Retrying { try await api.hc2.nodes.unlink(nodeId, keepChecks: keepChecks) }
            onResult(result)
            dismiss()
        } catch is CancellationError {
        } catch {
            inlineError = ErrorText(error).message.nonBlank ?? error.localizedDescription
        }
    }
}
