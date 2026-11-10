import SwiftUI
import IPv64

/// Android `ChannelItemView`: name, type + last use, status chips, last error.
struct ChannelRow: View {
    let channel: HC2Channel
    let isThisDevice: Bool
    let awaitingVerification: Bool
    let onVerify: () -> Void

    private var subtitle: String {
        let type = channel.typeLabel ?? channel.type?.rawValue ?? ""
        let used = Formatters.ago(channel.lastUsed).map { String(localized: "Last used: \($0)") }
            ?? String(localized: "Never used")
        return type.isEmpty ? used : type + "\n" + used
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: ChannelLogic.systemImage(type: channel.type?.rawValue))
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: ChannelLogic.displayName(channel))
                    Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                }
                Spacer(minLength: 8)
                ChannelChips(channel: channel, isThisDevice: isThisDevice,
                             awaitingVerification: awaitingVerification, onVerify: onVerify)
            }
            if let error = channel.lastError?.nonBlank {
                Text(verbatim: error.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.footnote)
                    .foregroundStyle(Color.ipv64Red)
            }
        }
    }
}

private struct ChannelChips: View {
    let channel: HC2Channel
    let isThisDevice: Bool
    let awaitingVerification: Bool
    let onVerify: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if isThisDevice { StatusChip("This device", color: .ipv64Teal) }
            if channel.default == true { StatusChip("Default", color: .ipv64Blue) }
            if channel.enabled == false { StatusChip("Disabled", color: .ipv64Gray) }
            if awaitingVerification {
                Button(action: onVerify) { StatusChip("Not verified", color: .ipv64Orange) }
                    .buttonStyle(.borderless)
                    .accessibilityHint(Text("Verify channel"))
            }
        }
    }
}
