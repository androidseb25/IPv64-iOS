import SwiftUI
import IPv64

/// "Edit node" sheet (cloud nodes): name, location, remote management. Sends only changed values.
struct NodeEditSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    let nodeId: String
    let info: NodeInfo
    let onSaved: (HC2Node) -> Void

    @State private var name: String
    @State private var location: String
    @State private var remote: String
    @State private var error: String?
    @State private var isBusy = false

    init(nodeId: String, info: NodeInfo, onSaved: @escaping (HC2Node) -> Void) {
        self.nodeId = nodeId
        self.info = info
        self.onSaved = onSaved
        _name = State(initialValue: info.name ?? "")
        _location = State(initialValue: info.location ?? "")
        _remote = State(initialValue: info.remote ?? "full")
    }

    private var changed: Bool {
        name.trimmingCharacters(in: .whitespaces) != (info.name ?? "") || location.trimmingCharacters(in: .whitespaces) != (info.location ?? "")
            || remote != (info.remote ?? "full")
    }

    var body: some View {
        NodeFormSheet(title: "Edit node", confirmLabel: "Save", confirmEnabled: changed && name.nonBlank != nil,
                      isBusy: isBusy, onConfirm: { Task { await save() } }) {
            Section("Node") {
                TextField("Name", text: $name)
                TextField("Location", text: $location)
            }
            Section {
                Picker("Remote management", selection: $remote) {
                    Text("Full").tag("full")
                    Text("Read only").tag("read")
                    Text("Off").tag("off")
                }
            } header: {
                Text("Remote management")
            } footer: {
                Text(verbatim: remoteDescription(remote))
            }
            if let error { Section { Text(verbatim: error).font(.footnote).foregroundStyle(Color.ipv64Red) } }
        }
    }

    private func save() async {
        let newName = name.trimmingCharacters(in: .whitespaces)
        let newLocation = location.trimmingCharacters(in: .whitespaces)
        isBusy = true
        defer { isBusy = false }
        do {
            let updated = try await ipv64Retrying {
                try await session.api.hc2.nodes.update(
                    nodeId, name: newName != (info.name ?? "") ? newName : nil,
                    location: newLocation != (info.location ?? "") ? newLocation : nil,
                    remoteManagement: remote != (info.remote ?? "full") ? HC2RemoteManagement(rawValue: remote) : nil)
            }
            onSaved(updated)
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            self.error = ErrorText(error).inlineText
        }
    }
}

/// "Resolve conflict" sheet: number + side, then the caller confirms the command.
struct ResolveConflictSheet: View {
    let onContinue: (NodeCommand) -> Void

    @State private var number = ""
    @State private var keep = "server"

    var body: some View {
        NodeFormSheet(title: "Resolve conflict", confirmLabel: "Continue", confirmSystemImage: "chevron.right",
                      confirmEnabled: Int(number) != nil, onConfirm: {
            guard let id = Int(number) else { return }
            onContinue(NodeCommand(name: .resolveConflict, args: HC2CommandArguments(id: id, keep: HC2ConflictResolution(rawValue: keep))))
        }) {
            Section {
                Text("Enter the conflict number shown on the node and choose which version to keep.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                TextField("Conflict number", text: $number)
                    .keyboardType(.numberPad)
                    .onChange(of: number) { _, new in
                        let digits = new.filter(\.isNumber)
                        if digits != new { number = digits }
                    }
                Picker("Keep", selection: $keep) {
                    Text("Server version (ipv64.net)").tag("server")
                    Text("Local version (node)").tag("local")
                }
            }
        }
    }
}

/// "Unlink node?" with the typed confirmation (Android AlertDialog; a sheet on iOS because of the switch and text field).
struct NodeUnlinkSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    let nodeId: String
    let name: String
    let onResult: (HC2NodeUnlinkResult) -> Void

    @State private var keepChecks = true
    @State private var typed = ""
    @State private var error: String?
    @State private var isBusy = false

    private var phrase: String { name.trimmingCharacters(in: .whitespaces).nonBlank ?? "unlink" }

    var body: some View {
        NodeFormSheet(title: "Unlink node?", confirmLabel: "Unlink", confirmSystemImage: "link.badge.minus",
                      confirmEnabled: typed.trimmingCharacters(in: .whitespaces) == phrase, isBusy: isBusy, destructive: true,
                      onConfirm: { Task { await unlink() } }) {
            Section {
                Text("The access token of \"\(name)\" is revoked. The node keeps running standalone but no longer syncs with ipv64.net. This cannot be undone.")
            }
            Section {
                Toggle("Keep checks as online checks", isOn: $keepChecks)
            } footer: {
                Text(keepChecks ? "Checks with a public target continue as online checks."
                     : "The checks of this node are not continued and will be deleted.")
            }
            Section {
                TextField(phrase, text: $typed).textInputAutocapitalization(.never).autocorrectionDisabled()
            } footer: {
                Text("Type \"\(phrase)\" to confirm.")
            }
            if let error { Section { Text(verbatim: error).font(.footnote).foregroundStyle(Color.ipv64Red) } }
        }
    }

    private func unlink() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await ipv64Retrying { try await session.api.hc2.nodes.unlink(nodeId, keepChecks: keepChecks) }
            onResult(result)
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            self.error = ErrorText(error).inlineText
        }
    }
}
