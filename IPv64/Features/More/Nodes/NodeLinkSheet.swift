import SwiftUI
import IPv64

/// "Link node" sheet (spec 04 §2): code from `ipv64 link`, location, remote management.
struct NodeLinkSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// Called after the code was accepted, with the `linkedAt` snapshot taken before linking.
    let onLinked: ([String: Date?]) -> Void

    @State private var code = ""
    @State private var location = ""
    @State private var remote = "full"
    @State private var error: String?
    @State private var isBusy = false

    private var raw: String { rawLinkCode(code) }

    var body: some View {
        NodeFormSheet(title: "Link node", confirmLabel: "Link", confirmSystemImage: "link",
                      confirmEnabled: raw.count == 8, isBusy: isBusy, onConfirm: { Task { await link() } }) {
            Section {
                Text("Open \"ipv64 link\" on your Node64 to get an 8-character code. After linking, the node fetches its access token by itself.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Node") {
                LabeledContent("Code") {
                    TextField("ABCD-EFGH", text: $code)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: code) { _, new in
                            let masked = maskedLinkCode(rawLinkCode(new))
                            if masked != new { code = masked }
                            error = nil
                        }
                }
            }
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
                Text(verbatim: remoteDescription(remote))
            }
            if isBusy { Section { ProgressView().progressViewStyle(.linear) } }
            if let error { Section { Text(verbatim: error).font(.footnote).foregroundStyle(Color.ipv64Red) } }
        }
    }

    private func link() async {
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            let list = try await ipv64Retrying { try await session.api.hc2.nodes.list() }
            let before = Dictionary(uniqueKeysWithValues: list.map { ($0.nodeID, $0.linkedAt) })
            let result = try await ipv64Retrying {
                try await session.api.hc2.nodes.link(
                    code: maskedLinkCode(raw), location: location.trimmingCharacters(in: .whitespaces).nonBlank,
                    remoteManagement: HC2RemoteManagement(rawValue: remote))
            }
            if result.accepted == false {
                error = result.detail?.nonBlank ?? String(localized: "The code was not accepted.")
                return
            }
            onLinked(before)
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            self.error = ErrorText(error).inlineText
        }
    }
}
