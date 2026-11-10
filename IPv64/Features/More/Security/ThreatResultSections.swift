import SwiftUI
import IPv64

/// Result sections of an IP lookup (spec 04 §11).
struct ThreatResultSections: View {
    let result: ThreatIP
    @Environment(\.openURL) private var openURL

    private var status: (label: LocalizedStringKey, color: Color) {
        switch result.status {
        case .listed: ("Listed", .ipv64Red)
        case .notListed: ("Not listed", .ipv64Green)
        case .released: ("Released", .ipv64Orange)
        case .allowlisted: ("Allowlisted", .ipv64Teal)
        default: result.listed == true ? ("Listed", .ipv64Red) : ("Not listed", .ipv64Green)
        }
    }

    var body: some View {
        Section("Result") {
            HStack {
                Text(verbatim: result.ip ?? "").font(.body.monospaced())
                Spacer()
                StatusChip(status.label, color: status.color)
            }
            if let score = result.score {
                ProgressView(value: Double(min(max(score, 0), 100)), total: 100)
            }
            InfoRow("Family", value: result.family.map { "IPv\($0)" })
            InfoRow("Score", value: result.score.map { "\(min(max($0, 0), 100)) / 100" })
            InfoRow("Reporting accounts", value: result.accounts.map { Formatters.count($0) })
            InfoRow("Country", value: SecurityLogic.countryFlag(result.country))
            InfoRow("ASN", value: result.asn.map { "AS\($0)" })
            InfoRow("First seen", value: result.firstSeen)
            InfoRow("Last seen", value: result.lastSeen)
            InfoRow("Release", value: releaseText)
            InfoRow("Release valid until", value: result.release?.protectedUntil.map { Formatters.germanTime($0) })
        }
        if let lists = result.lists, !lists.isEmpty { chips("Lists", lists.map(\.rawValue)) }
        if let kinds = result.kinds, !kinds.isEmpty { chips("Attack kinds", kinds) }
        if let ports = result.ports, !ports.isEmpty {
            Section {
                ForEach(Array(ports.enumerated()), id: \.offset) { _, port in
                    LabeledContent(port.service ?? "–") { Text(verbatim: port.port.map(String.init) ?? "–").font(.body.monospaced()) }
                }
            } header: {
                Text("Attacked ports")
            } footer: {
                Text("Only ports reported by at least two accounts are shown.")
            }
        }
        if result.listed != true, result.status == .notListed {
            Section { Text("No further details are available for IPs that are not listed.").foregroundStyle(.secondary) }
        }
        if let details = result.details, details.hasPrefix("https://"), let url = URL(string: details) {
            Section {
                Button("Explanation and release request", systemImage: "arrow.up.right.square") { openURL(url) }
            }
        }
    }

    private var releaseText: String? {
        switch result.release?.status {
        case .none?: String(localized: "No release")
        case .inReview?: String(localized: "In review")
        case .released?: String(localized: "Released")
        case .allowlisted?: String(localized: "Allowlisted")
        case .rejected?: String(localized: "Rejected")
        default: nil
        }
    }

    private func chips(_ title: LocalizedStringKey, _ values: [String]) -> some View {
        Section(title) {
            FlowChips(values: values)
        }
    }
}

/// Wrapped, non-interactive capsule chips.
private struct FlowChips: View {
    let values: [String]

    var body: some View {
        WrapLayout(spacing: 6) {
            ForEach(values, id: \.self) { value in
                Text(verbatim: value).font(.subheadline)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
    }
}

private struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? 300, subviews)
        return CGSize(width: proposal.width ?? 300, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, origin) in arrange(width: bounds.width, subviews).origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, _ subviews: Subviews) -> (origins: [CGPoint], height: CGFloat) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (origins, y + rowHeight)
    }
}
