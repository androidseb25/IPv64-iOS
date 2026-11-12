import SwiftUI
import IPv64

/// Healthcheck row (Android layout): name, type · target, last check, status tag.
struct HealthcheckItemView: View {
    let name: String?
    let typeLine: String
    let metaLine: String?
    let state: Hc2StateUi
    var isBusy = false

    /// Account check.
    init(check: HC2Check, isBusy: Bool = false) {
        var meta: [String] = []
        if let last = check.state?.lastCheckAt {
            meta.append(String(localized: "Checked \(last.formatted(.relative(presentation: .named)))"))
        }
        if let latency = check.state?.lastLatencyMS { meta.append("\(Int(latency.rounded())) ms") }
        if let node = check.nodeName?.nonBlank, (check.execution ?? .online) != .online { meta.append(node) }
        self.init(name: check.name, type: check.type?.label, target: check.target, meta: meta,
                  state: Hc2StateUi.from(check), isBusy: isBusy)
    }

    /// Check of a connected node.
    init(nodeCheck check: Node64.Check, isBusy: Bool = false) {
        var meta: [String] = []
        if let last = HcFormat.real(nodeDate(check.state?.lastCheckAt)) {
            meta.append(String(localized: "Checked \(last.formatted(.relative(presentation: .named)))"))
        }
        if let latency = check.state?.lastLatencyMS { meta.append("\(Int(latency.rounded())) ms") }
        self.init(name: check.name, type: check.type?.label, target: check.target, meta: meta,
                  state: check.uiState, isBusy: isBusy)
    }

    private init(name: String?, type: String?, target: String?, meta: [String], state: Hc2StateUi, isBusy: Bool) {
        self.name = name
        let type = type ?? "Unknown"
        typeLine = target?.nonBlank.map { "\(type) · \($0)" } ?? type
        metaLine = meta.isEmpty ? nil : meta.joined(separator: " · ")
        self.state = state
        self.isBusy = isBusy
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name?.nonBlank ?? String(localized: "(unnamed)"))
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
