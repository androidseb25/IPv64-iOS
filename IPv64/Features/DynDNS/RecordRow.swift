import SwiftUI
import IPv64

/// One DNS record row of the domain detail: tap edits, swipe/long press deletes, locked records are inert.
struct RecordRow: View {
    let record: Record
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var locked: Bool { DynDNSLogic.isLocked(record.state) }

    private var subtitle: String {
        var lines = [record.content ?? "–",
                     "TTL \(record.ttl.map(String.init) ?? "–") · \(Formatters.germanTime(record.updatedAt, fallback: "–"))"]
        if let reason = DynDNSLogic.lockReason(record.state) { lines.append(reason) }
        return lines.joined(separator: "\n")
    }

    private var showsState: Bool { (record.state != nil && record.state != .active) || record.pendingDNS == true }

    var body: some View {
        let row = HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: DynDNSLogic.prefixLabel(record.prefix))
                Text(verbatim: subtitle).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(6)
            }
            Spacer(minLength: 8)
            if showsState {
                VStack(alignment: .trailing, spacing: 4) {
                    if let state = record.state, state != .active, let label = DynDNSLogic.stateLabel(state) {
                        StatusChip(verbatim: label, color: locked ? .ipv64Teal : .ipv64Gray)
                    }
                    if record.pendingDNS == true { StatusChip("DNS pending", color: .ipv64Orange) }
                }
            }
            if locked {
                Image(systemName: "lock.fill").foregroundStyle(.secondary).accessibilityLabel("Locked")
            }
        }
        .contentShape(Rectangle())

        if locked {
            row
        } else {
            row
                .onTapGesture(perform: onEdit)
                .accessibilityAddTraits(.isButton)
                .swipeActions {
                    Button("Delete record", systemImage: "trash", role: .destructive, action: onDelete)
                }
                .contextMenu {
                    Button("Edit", systemImage: "pencil", action: onEdit)
                    Button("Delete record", systemImage: "trash", role: .destructive, action: onDelete)
                }
        }
    }
}
