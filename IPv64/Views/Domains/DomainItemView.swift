import SwiftUI
import IPv64

/// Domain row (Android layout): name, updates and wildcard in one line, tag for the IP check.
struct DomainItemView: View {
    let row: DomainRow
    let status: DynDNSLogic.IpStatus

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("Updates: \(row.updates) · Wildcard: \(HcFormat.yesNo(row.wildcard) ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(status.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(status.color.opacity(0.15), in: Capsule())
                .fixedSize()
        }
    }
}

extension DynDNSLogic.IpStatus {
    var label: LocalizedStringKey {
        switch self {
        case .checking: "Checking"
        case .noIp: "No IP"
        case .unknown: "IP unknown"
        case .differs: "IP differs"
        case .matches: "IP matches"
        }
    }

    var color: Color {
        switch self {
        case .differs: .red
        case .matches: .green
        default: .gray
        }
    }
}

#Preview {
    List {
        DomainItemView(row: DomainRow(name: "test.iot64.de", kind: .dyndns, wildcard: true, updates: 12), status: .matches)
        DomainItemView(row: DomainRow(name: "nas.home64.de", kind: .dyndns, wildcard: false, updates: 0), status: .checking)
    }
}
