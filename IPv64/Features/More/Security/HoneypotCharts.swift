import SwiftUI
import Charts

struct DayValue: Identifiable {
    let day: String
    let value: Int
    var id: String { day }
}

/// Bars per day with tap/drag read-out (spec 04 §10.6).
struct DayBarChart: View {
    let days: [DayValue]
    let color: Color
    @State private var selected: String?

    private var readout: Text {
        guard let selected, let item = days.first(where: { $0.day == selected }) else {
            return Text("Tap a bar for details")
        }
        return Text(verbatim: "\(SecurityLogic.shortDay(item.day))  ") + Text(verbatim: Formatters.count(item.value)).bold()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            readout.font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Chart(days) { item in
                BarMark(x: .value("Day", item.day), y: .value("Events", item.value))
                    .foregroundStyle(color.opacity(selected == nil || selected == item.day ? 1 : 0.4))
                    .cornerRadius(3)
            }
            .chartXSelection(value: $selected)
            .chartXAxis {
                AxisMarks(values: [days.first?.day, days.last?.day].compactMap { $0 }) { value in
                    AxisValueLabel { Text(verbatim: SecurityLogic.shortDay(value.as(String.self) ?? "")) }
                }
            }
            .frame(height: 120)
            .accessibilityLabel(Text("Bar chart with \(days.count) values, maximum \(Formatters.count(days.map(\.value).max() ?? 0))"))
            Text("max \(Formatters.count(days.map(\.value).max() ?? 0))").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct RankingEntry: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
    var detail: String?
    var monospaced = false
}

/// Titled ranking list with proportional bars (RankingCard).
struct RankingSection: View {
    let title: LocalizedStringKey
    let entries: [RankingEntry]

    var body: some View {
        Section(title) {
            if entries.isEmpty {
                Text("No data").foregroundStyle(.secondary)
            }
            let top = max(entries.map(\.value).max() ?? 1, 1)
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: entry.label).font(entry.monospaced ? .body.monospaced() : .body).lineLimit(2)
                        Spacer(minLength: 8)
                        Text(verbatim: entry.detail ?? Formatters.count(entry.value)).font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: entry.value == 0 ? 0 : min(max(Double(entry.value) / Double(top), 0.02), 1))
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
