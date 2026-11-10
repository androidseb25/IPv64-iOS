import SwiftUI
import IPv64

/// Account check row (spec 02 B1 `HealthcheckRow`).
struct HealthcheckRow: View {
    let check: HC2Check

    private var subtitle: [String] {
        let type = check.type.label
        var lines = [check.target?.nonBlank.map { "\(type) · \($0)" } ?? type]
        var meta: [String] = []
        if let last = check.state?.lastCheckAt { meta.append(String(localized: "Checked \(Formatters.relative(last))")) }
        if let latency = check.state?.lastLatencyMS { meta.append(Formatters.latency(latency)) }
        if let exec = healthcheckExecutionLabel(check.execution, nodeName: check.nodeName) { meta.append(exec) }
        if !meta.isEmpty { lines.append(meta.joined(separator: " · ")) }
        return lines
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(check.name?.nonBlank ?? String(localized: "(unnamed)")).lineLimit(1)
                Text(verbatim: subtitle.joined(separator: "\n"))
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            StatusChip(state: Hc2StateUi.from(check.state?.state?.rawValue, paused: check.paused))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Node check row (spec 02 B1 `NodeCheckRow`).
struct NodeCheckRow: View {
    let check: Node64.Check

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(check.name?.nonBlank ?? String(localized: "(unnamed)")).lineLimit(1)
                Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            StatusChip(verbatim: nodeCheckStateLabel(check.state?.state), color: nodeCheckStateColor(check.state?.state))
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let type = (check.type?.rawValue ?? "").uppercased()
        guard let target = check.target?.nonBlank else { return type }
        return type.isEmpty ? target : "\(type) · \(target)"
    }
}

/// "New healthcheck" target choice (spec 02 B1): account or one connected node.
struct HealthcheckTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// (nodeId, name) of nodes that offer checks.
    let nodes: [(id: String, name: String)]
    let onAccount: () -> Void
    let onNode: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    dismiss()
                    onAccount()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Account healthcheck")
                            Text("Runs from ipv64.net locations").font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "cloud") }
                }
                ForEach(nodes, id: \.id) { node in
                    Button {
                        dismiss()
                        onNode(node.id)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("On node \(node.name)")
                                Text("Runs locally on \(node.name)").font(.subheadline).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "network") }
                    }
                }
            }
            .foregroundStyle(.primary)
            .navigationTitle("New healthcheck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
