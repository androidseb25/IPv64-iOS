import SwiftUI

/// Mode and healthcheck choice for enabling CDN64 on one host. Modes 1 and 2 are selectable, 3 is info only.
/// Owns the busy state: `enable` runs while the sheet shows a spinner and cannot be dismissed.
struct CdnModeForm: View {
    @Environment(\.dismiss) private var dismiss
    let hostLabel: String?
    let enable: (_ mode: Int, _ healthcheck: Bool) async -> Void

    @State private var mode = 1
    @State private var healthcheck = false
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                if let hostLabel { Text(verbatim: hostLabel).font(.headline) }
                Text("Makes this host reachable from the internet via the ipv64 CDN64 servers, over IPv4 and IPv6. The node builds a tunnel outwards; no port needs to be open at home.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                ForEach([1, 2], id: \.self) { m in
                    Button { mode = m } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: ProxyLogic.modeShort(m) + " · " + ProxyLogic.cdnModeTitle(m))
                                    .font(.body).foregroundStyle(.primary)
                                Text(verbatim: ProxyLogic.cdnModeDescription(m)).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if mode == m { Image(systemName: "checkmark").foregroundStyle(.tint) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(mode == m ? .isSelected : [])
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: ProxyLogic.modeShort(3) + " · " + ProxyLogic.cdnModeTitle(3)).font(.body)
                    Text(verbatim: ProxyLogic.cdnModeDescription(3)).font(.subheadline)
                    if let url = URL(string: "https://ipv64.net/cdn64") {
                        Link("ipv64.net/cdn64", destination: url).font(.subheadline)
                    }
                }
                .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Create healthcheck", isOn: $healthcheck)
            }
        }
        .disabled(busy)
        .navigationTitle("Enable CDN64")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(busy)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if busy {
                    ProgressView()
                } else {
                    Button("Enable", systemImage: "checkmark") {
                        busy = true
                        Task {
                            await enable(mode, healthcheck)
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(busy)
    }
}

/// Sheet for one known host.
struct CdnModeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let hostLabel: String?
    let enable: (_ mode: Int, _ healthcheck: Bool) async -> Void

    var body: some View {
        NavigationStack {
            CdnModeForm(hostLabel: hostLabel, enable: enable)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                }
        }
        .appReadableWidth()
        .presentationDetents([.large])
    }
}

/// Host picker, then the mode form.
struct CdnEnableFlow: View {
    @Environment(\.dismiss) private var dismiss
    let choices: [CdnHostChoice]
    let enable: (CdnHostChoice, Int, Bool) async -> Void

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
                            Text(verbatim: choice.nodeName).font(.subheadline).foregroundStyle(.secondary)
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
                    await enable(choice, mode, healthcheck)
                }
            }
        }
        .appReadableWidth()
        .presentationDetents([.large])
    }
}
