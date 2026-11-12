import SwiftUI
import IPv64

/// Channel choice: default channels or a native multi-select list (pushed inside the sheet).
/// Channels themselves are managed elsewhere.
struct HealthcheckChannelPicker: View {
    @Binding var useDefault: Bool
    @Binding var selected: Set<Int>
    let channels: [HC2Channel]
    let types: [HC2ChannelType]?

    private var summary: String {
        if useDefault { return String(localized: "Default channels") }
        let names = channels.filter { selected.contains($0.id) }.map(HcFormat.channelName)
        return names.isEmpty ? String(localized: "None") : names.joined(separator: ", ")
    }

    var body: some View {
        NavigationLink {
            HealthcheckChannelList(useDefault: $useDefault, selected: $selected, channels: channels, types: types)
        } label: {
            LabeledContent("Channels") { Text(verbatim: summary).lineLimit(1) }
        }
    }
}

private struct HealthcheckChannelList: View {
    @Binding var useDefault: Bool
    @Binding var selected: Set<Int>
    let channels: [HC2Channel]
    let types: [HC2ChannelType]?

    var body: some View {
        List {
            Section {
                Toggle("Default channels", isOn: $useDefault)
            } footer: {
                Text("Notify all channels marked as default")
            }
            if !useDefault {
                Section("Selected channels") {
                    if channels.isEmpty {
                        Text("No channels yet. Create one under Monitoring › Channels.").foregroundStyle(.secondary)
                    }
                    ForEach(channels.filter { $0.id >= 0 }) { channel in
                        Button {
                            if selected.contains(channel.id) { selected.remove(channel.id) } else { selected.insert(channel.id) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: HcFormat.channelName(channel))
                                    if let warning = warning(channel) {
                                        Text(verbatim: warning).font(.caption).foregroundStyle(.red)
                                    }
                                }
                                Spacer()
                                if selected.contains(channel.id) {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .tint(.primary)
                        .accessibilityAddTraits(selected.contains(channel.id) ? .isSelected : [])
                    }
                }
            }
        }
        .navigationTitle("Channels")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// "Disabled" / "Not verified" joined by " · ".
    private func warning(_ channel: HC2Channel) -> String? {
        var parts: [String] = []
        if channel.enabled == false { parts.append(String(localized: "Disabled")) }
        if channel.verified != true && needsVerification(channel.type) { parts.append(String(localized: "Not verified")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func needsVerification(_ type: HC2ChannelKind?) -> Bool {
        if let flag = types?.first(where: { $0.type == type })?.needsVerification { return flag }
        return type == .ipv64Mail || type == .ipv64SMS
    }
}
