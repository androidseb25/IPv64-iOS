import SwiftUI
import IPv64

/// "Link node": code from `ipv64 link`, location, remote management. Locked while linking.
struct NodeLinkSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// Called after the code was accepted, with the `linkedAt` of every node taken before linking.
    let onLinked: ([String: Date?]) -> Void

    @State private var code = ""
    @State private var location = ""
    @State private var remote = "full"
    @State private var inlineError: String?
    @State private var isLinking = false

    private var raw: String { NodesLogic.rawLinkCode(code) }

    var body: some View {
        DynDNSSheet(title: "Link node",
                    subtitle: String(localized: "Open \"ipv64 link\" on your Node64 to get an 8-character code. After linking, the node fetches its access token by itself."),
                    confirmLabel: "Link", confirmEnabled: raw.count == 8, isBusy: isLinking,
                    onConfirm: { Task { await link() } }) {
            Section("Node") {
                TextField("Code", text: $code, prompt: Text(verbatim: "ABCD-EFGH"))
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: code) { _, new in
                        let masked = NodesLogic.maskedLinkCode(NodesLogic.rawLinkCode(new))
                        if masked != new { code = masked }
                        inlineError = nil
                    }
            }
            .disabled(isLinking)
            Section {
                TextField("Location (optional)", text: $location)
                Picker("Remote management", selection: $remote) {
                    Text("Full").tag("full")
                    Text("Read only").tag("read")
                    Text("Off").tag("off")
                }
            } header: {
                Text("Options")
            } footer: {
                Text(NodesLogic.remoteDescription(remote))
            }
            .disabled(isLinking)
            if isLinking {
                Section {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Linking...").foregroundStyle(.secondary)
                    }
                }
            }
            if let inlineError {
                Section { Text(inlineError).font(.footnote).foregroundStyle(.red) }
            }
        }
        .appReadableWidth()
        .presentationDetents([.large])
    }

    private func link() async {
        let api = session.api
        isLinking = true
        inlineError = nil
        defer { isLinking = false }
        do {
            let list = try await ipv64Retrying { try await api.hc2.nodes.list() }
            let before = Dictionary(list.map { ($0.nodeID, $0.linkedAt) }, uniquingKeysWith: { first, _ in first })
            let result = try await ipv64Retrying {
                try await api.hc2.nodes.link(
                    code: NodesLogic.maskedLinkCode(raw), location: location.trimmingCharacters(in: .whitespaces).nonBlank,
                    remoteManagement: HC2RemoteManagement(rawValue: remote))
            }
            if result.accepted == false {
                inlineError = result.detail?.nonBlank ?? String(localized: "The code was not accepted.")
                return
            }
            onLinked(before)
            dismiss()
        } catch is CancellationError {
        } catch {
            inlineError = ErrorText(error).message.nonBlank ?? error.localizedDescription
        }
    }
}
