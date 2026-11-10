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
        let state = Hc2StateUi.from(check.state?.state?.rawValue, paused: check.paused)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().fill(state.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.name?.nonBlank ?? String(localized: "(unnamed)")).font(.headline).lineLimit(1)
                Text(verbatim: subtitle.joined(separator: "\n")).font(.subheadline).lineLimit(2)
                Text(state.label).font(.caption).foregroundStyle(state.color)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Node check row (spec 02 B1 `NodeCheckRow`).
struct NodeCheckRow: View {
    let check: Node64.Check

    var body: some View {
        let color = nodeCheckStateColor(check.state?.state)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.name?.nonBlank ?? String(localized: "(unnamed)")).font(.headline).lineLimit(1)
                Text(verbatim: subtitle).font(.subheadline).lineLimit(1)
                Text(verbatim: nodeCheckStateLabel(check.state?.state)).font(.caption).foregroundStyle(color)
            }
        }
        .padding(.vertical, 4)
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

/// Coloured counter tile of the 2.0 healthcheck list; tapping it filters the list.
struct HealthcheckCountTile: View {
    let filter: HcStatusFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    private var color: Color {
        switch filter {
        case .up: .ipv64Green
        case .degraded: .ipv64Orange
        case .down: .ipv64Red
        case .paused: .ipv64Teal
        case .all: .ipv64Gray
        }
    }

    private var symbol: String {
        switch filter {
        case .up: "bolt.heart"
        case .degraded: "exclamationmark.triangle"
        case .down: "bell.badge"
        case .paused: "pause.circle"
        case .all: "list.bullet"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: filter.label).font(.system(.title3, design: .rounded)).bold().lineLimit(1)
                    Text(verbatim: "\(count)").font(.system(.title, design: .rounded))
                }
                Spacer()
                Image(systemName: symbol).font(.title2)
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(color.opacity(isSelected ? 1 : 0.85), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
