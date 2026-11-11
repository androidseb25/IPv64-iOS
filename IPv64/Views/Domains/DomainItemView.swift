import SwiftUI
import IPv64

/// Domain row: status dot, name, updates and wildcard, plus a tag for the IP check.
struct DomainItemView: View {
    let row: DomainRow
    let status: DynDNSLogic.IpStatus

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)
                .foregroundStyle(status.color)
                .padding(.trailing, 5)
                .padding(.top, 8)
            VStack(alignment: .leading) {
                Text(row.name)
                    .lineLimit(1)
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.bottom, 2)
                Text("Updates: \(row.updates)")
                Text("Wildcard: \(row.wildcard ? "yes" : "no")")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(status.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(status.color.opacity(0.15), in: Capsule())
                .padding(.top, 6)
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
