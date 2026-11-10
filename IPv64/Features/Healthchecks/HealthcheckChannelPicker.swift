import SwiftUI
import IPv64

/// Read-only picker of the hc2 notification channels (spec 02 B4 `ChannelPicker`); channels are managed under More.
struct HealthcheckChannelPicker: View {
    @Binding var useDefault: Bool
    @Binding var selected: Set<Int>
    let channels: [HC2Channel]
    let types: [HC2ChannelType]?

    var body: some View {
        option("Default channels", subtitle: "Notify all channels marked as default", isOn: useDefault) {
            useDefault = true
        }
        option("Selected channels", subtitle: nil, isOn: !useDefault) { useDefault = false }
        if !useDefault {
            if channels.isEmpty {
                Text("No channels yet. Create one under Monitoring › Channels.").foregroundStyle(.secondary)
            }
            ForEach(channels.filter { $0.id >= 0 }) { channel in
                Button {
                    if selected.contains(channel.id) { selected.remove(channel.id) } else { selected.insert(channel.id) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selected.contains(channel.id) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(selected.contains(channel.id) ? Color.accentColor : .secondary)
                        Image(systemName: icon(channel.type)).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: channelDisplayName(channel))
                            if let warning = warning(channel) {
                                Text(verbatim: warning).font(.caption).foregroundStyle(Color.ipv64Red)
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected.contains(channel.id) ? .isSelected : [])
            }
        }
    }

    private func option(_ title: LocalizedStringKey, subtitle: LocalizedStringKey?, isOn: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
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

    private func icon(_ type: HC2ChannelKind?) -> String {
        switch type {
        case .ipv64Mail, .smtp: "envelope"
        case .ipv64SMS: "message"
        case .app: "iphone"
        case .telegram: "paperplane"
        case .discord: "bubble.left.and.bubble.right"
        case .ntfy, .gotify, .pushover: "bell"
        case .webhook: "link"
        default: "bell.badge"
        }
    }
}
