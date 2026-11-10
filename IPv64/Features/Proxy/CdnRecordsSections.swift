import SwiftUI
import IPv64

/// Collapsible "DNS records" (loads on expand).
struct CdnRecordsSection: View {
    @Binding var expanded: Bool
    let records: [Record]?
    let enabled: Bool
    let refresh: () -> Void
    let enable: (Record) -> Void
    let disable: (Record) -> Void

    var body: some View {
        Section {
            DisclosureGroup("DNS records", isExpanded: $expanded) {
                if let records {
                    Button("Refresh", systemImage: "arrow.clockwise", action: refresh).disabled(!enabled)
                    if records.isEmpty {
                        Text("No A or AAAA records on this domain.").foregroundStyle(.secondary)
                    }
                    ForEach(records) { record in
                        RecordRow(record: record, enabled: enabled, enable: enable, disable: disable)
                    }
                } else {
                    Text("Loading records…").foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct RecordRow: View {
    let record: Record
    let enabled: Bool
    let enable: (Record) -> Void
    let disable: (Record) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: record.cdnTitle)
                    if let content = record.content, !content.isEmpty {
                        Text(verbatim: content).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                StatusChip(verbatim: record.cdnStateLabel, color: record.cdnStateColor)
            }
            if record.pendingDNS == true || record.canEnableCdn || record.canDisableCdn {
                HStack {
                    if record.pendingDNS == true { StatusChip("DNS updating", color: .ipv64Orange) }
                    Spacer()
                    if record.canEnableCdn { Button("Enable") { enable(record) }.disabled(!enabled) }
                    if record.canDisableCdn { Button("Disable") { disable(record) }.disabled(!enabled) }
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

/// Collapsible "Access list" (loads on expand).
struct CdnAccessSection: View {
    @Binding var expanded: Bool
    let entries: [AccessListEntry]?
    let settingsText: String
    let enabled: Bool
    let refresh: () -> Void
    let add: () -> Void
    let remove: (AccessListEntry) -> Void

    var body: some View {
        Section {
            DisclosureGroup("Access list", isExpanded: $expanded) {
                Text(verbatim: settingsText).font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                    Spacer()
                    Button("Add", systemImage: "plus", action: add).disabled(entries == nil)
                }
                .buttonStyle(.borderless).disabled(!enabled)
                if let entries {
                    if entries.isEmpty { Text("The access list is empty.").foregroundStyle(.secondary) }
                    ForEach(entries) { entry in
                        HStack {
                            Text(verbatim: entry.address ?? "").font(.body.monospaced())
                            Spacer()
                            Button("Remove entry", systemImage: "xmark.circle", action: { remove(entry) })
                                .labelStyle(.iconOnly).buttonStyle(.borderless).disabled(!enabled)
                        }
                    }
                } else {
                    Text("Loading access list…").foregroundStyle(.secondary)
                }
            }
        }
    }
}
