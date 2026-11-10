import SwiftUI

/// Mode + healthcheck form (spec 03 §4 step B). Modes 1 and 2 are selectable rows, 3 is info only.
struct CdnModeForm: View {
    let hostLabel: String?
    let onConfirm: (_ mode: Int, _ healthcheck: Bool) -> Void

    @State private var mode = 1
    @State private var healthcheck = false

    var body: some View {
        Form {
            Section {
                if let hostLabel { Text(verbatim: hostLabel).font(.headline) }
                Text("Makes this host reachable from the internet via the ipv64 CDN64 servers, over IPv4 and IPv6. The node builds a tunnel outwards; no port needs to be open at home.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                ForEach([1, 2, 3], id: \.self) { m in
                    ModeRow(mode: m, selected: mode == m) { mode = m }
                }
            }
            Section {
                Toggle("Create healthcheck", isOn: $healthcheck)
            }
        }
        .navigationTitle("Enable CDN64")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Enable", systemImage: "checkmark") { onConfirm(mode, healthcheck) }
            }
        }
    }
}

private struct ModeRow: View {
    let mode: Int
    let selected: Bool
    let select: () -> Void

    private var selectable: Bool { mode != 3 }

    var body: some View {
        let label = ProxyLogic.cdnModeLabel(mode)
        Button(action: select) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark" : "")
                    .foregroundStyle(Color.accentColor).frame(width: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "Mode \(mode) · \(label.title)").font(.subheadline.weight(.semibold))
                    Text(verbatim: label.description).font(.subheadline).foregroundStyle(.secondary)
                    if let flow = ProxyLogic.cdnModeFlow(mode) {
                        Text(verbatim: flow).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
        .opacity(selectable ? 1 : 0.6)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Sheet for one known host (editor).
struct CdnModeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let hostLabel: String?
    let onConfirm: (_ mode: Int, _ healthcheck: Bool) -> Void

    var body: some View {
        NavigationStack {
            CdnModeForm(hostLabel: hostLabel) { mode, healthcheck in
                dismiss()
                onConfirm(mode, healthcheck)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }
}

/// Host picker, then the mode form (list flows).
struct CdnEnableFlow: View {
    @Environment(\.dismiss) private var dismiss
    let choices: [CdnHostChoice]
    let onEnable: (CdnHostChoice, Int, Bool) -> Void

    @State private var picked: CdnHostChoice?

    var body: some View {
        NavigationStack {
            List {
                if choices.isEmpty {
                    Text("All proxy hosts already use CDN64.").foregroundStyle(.secondary)
                }
                ForEach(choices) { choice in
                    Button { picked = choice } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: choice.label).font(.headline).foregroundStyle(.primary)
                            Text(verbatim: choice.nodeName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Enable CDN64 for a proxy host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
            }
            .navigationDestination(item: $picked) { choice in
                CdnModeForm(hostLabel: choice.label) { mode, healthcheck in
                    dismiss()
                    onEnable(choice, mode, healthcheck)
                }
            }
        }
        .presentationDetents([.large])
    }
}
