import SwiftUI
import Charts
import IPv64

/// Node module screen (spec 04 §4.2): read-only details of one module over the stored direct connection.
struct NodeModuleView: View {
    @Environment(ConnectedNodes.self) private var nodes

    let nodeId: String
    let module: String

    @State private var sections: [ModSection]?

    var body: some View {
        Group {
            if let client = nodes.client(for: nodeId) {
                List {
                    ForEach(sections ?? []) { ModSectionView(section: $0) }
                }
                .overlay { if sections == nil { ProgressView() } }
                .refreshable { sections = await NodeModuleLoader.load(client, module: module) }
                .task { sections = await NodeModuleLoader.load(client, module: module) }
            } else {
                ContentUnavailableView("No direct connection to this node.", systemImage: "network.slash")
            }
        }
        .navigationTitle(moduleLabel(module) ?? String(localized: "Module"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Tone {
    var color: Color {
        switch self {
        case .green: .ipv64Green
        case .red: .ipv64Red
        case .orange: .ipv64Orange
        case .gray: .ipv64Gray
        }
    }
}

private struct ModSectionView: View {
    let section: ModSection

    var body: some View {
        switch section.kind {
        case .error(let text):
            Section(section.title) { Text(verbatim: text).foregroundStyle(Color.ipv64Red) }
        case .facts(let facts):
            Section(section.title) {
                ForEach(facts.indices, id: \.self) { i in
                    LabeledContent(facts[i].0, value: facts[i].1)
                }
            }
        case .stats(let stats):
            Section(section.title) {
                StatTiles { ForEach(stats.indices, id: \.self) { StatTile(value: stats[$0].1, label: LocalizedStringKey(stats[$0].0)) } }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
        case .rows(let rows, let empty):
            Section(section.title) {
                if rows.isEmpty { Text(verbatim: empty).foregroundStyle(.secondary) }
                ForEach(rows.indices, id: \.self) { i in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: rows[i].title)
                            if let subtitle = rows[i].subtitle?.nonBlank { Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                        }
                        if let chip = rows[i].chip {
                            Spacer(minLength: 8)
                            StatusChip(verbatim: chip.text, color: chip.tone.color)
                        }
                    }
                }
            }
        case .bars(let bars):
            Section(section.title) { BarSeries(bars: bars) }
        case .ranks(let ranks, let mono):
            Section(section.title) {
                if ranks.isEmpty { Text("No data").foregroundStyle(.secondary) }
                let maxValue = ranks.map(\.value).max() ?? 0
                ForEach(ranks.indices, id: \.self) { RankView(row: ranks[$0], maxValue: maxValue, mono: mono) }
            }
        }
    }
}

private struct RankView: View {
    let row: RankRow
    let maxValue: Int
    let mono: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: row.label).font(mono ? .body.monospaced() : .body).lineLimit(2)
                Spacer(minLength: 8)
                Text(verbatim: row.detail).font(.footnote).foregroundStyle(.secondary)
            }
            ProgressView(value: row.value == 0 || maxValue == 0 ? 0 : min(max(Double(row.value) / Double(maxValue), 0.02), 1))
        }
    }
}

/// Bar chart of a time series with a tap-to-read line and first / max / last labels.
private struct BarSeries: View {
    let bars: [(label: String, value: Int)]
    @State private var selected: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let selected, bars.indices.contains(selected) {
                Text("\(bars[selected].label)  \(Formatters.count(bars[selected].value))").font(.caption.weight(.semibold))
            } else {
                Text("Tap a bar for details").font(.caption).foregroundStyle(.secondary)
            }
            Chart(bars.indices, id: \.self) { i in
                BarMark(x: .value("Time", i), y: .value("Events", bars[i].value))
                    .foregroundStyle(Color.accentColor.opacity(selected == nil || selected == i ? 1 : 0.4))
            }
            .chartXAxis(.hidden)
            .chartXSelection(value: $selected)
            .frame(height: 96)
            HStack {
                Text(verbatim: bars.first?.label ?? "")
                Spacer()
                Text("max \(Formatters.count(bars.map(\.value).max() ?? 0))")
                Spacer()
                Text(verbatim: bars.last?.label ?? "")
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bar chart with \(bars.count) values, maximum \(bars.map(\.value).max() ?? 0)")
    }
}
