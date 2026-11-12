import SwiftUI
import IPv64

/// Healthcheck row (Android layout): name, type · target, last check, status tag.
struct HealthcheckItemView: View {
    let check: HC2Check
    var isBusy = false

    private var state: Hc2StateUi { Hc2StateUi.from(check) }

    private var typeLine: String {
        let type = check.type?.label ?? "Unknown"
        guard let target = check.target?.nonBlank else { return type }
        return "\(type) · \(target)"
    }

    private var metaLine: String? {
        var parts: [String] = []
        if let last = check.state?.lastCheckAt {
            parts.append(String(localized: "Checked \(last.formatted(.relative(presentation: .named)))"))
        }
        if let latency = check.state?.lastLatencyMS { parts.append("\(Int(latency.rounded())) ms") }
        if let node = check.nodeName?.nonBlank, (check.execution ?? .online) != .online { parts.append(node) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(check.name?.nonBlank ?? String(localized: "(unnamed)"))
                    .font(.headline)
                    .lineLimit(1)
                Text(typeLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let metaLine {
                    Text(metaLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isBusy {
                ProgressView()
            } else {
                HealthcheckStateTag(state: state)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Status capsule shared by the list row and the detail header.
struct HealthcheckStateTag: View {
    let state: Hc2StateUi

    var body: some View { HealthcheckTag(text: LocalizedStringKey(state.label), color: state.color) }
}

struct HealthcheckTag: View {
    let text: LocalizedStringKey
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .fixedSize()
    }
}
