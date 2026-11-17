import SwiftUI
import Charts

/// Gradient on full screens only; off while the screen presents a sheet.
private struct MoreGradient: ViewModifier {
    let sheetShown: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(sheetShown ? .clear : .orange)
        } else {
            content
        }
    }
}

extension View {
    func moreGradient(sheetShown: Bool = false) -> some View { modifier(MoreGradient(sheetShown: sheetShown)) }

    /// Spinner in the toolbar while something runs (loading again or an action).
    func moreToolbarSpinner(_ busy: Bool) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) { if busy { ProgressView() } }.appVerticalPreferred()
        }
    }
}

struct MoreTag: View {
    let text: String
    let color: Color

    init(_ text: String, _ color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(verbatim: text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .fixedSize()
    }
}

/// KPI tile with a prominent number; stretches to the height of its grid row.
struct MoreKpiTile: View {
    let label: LocalizedStringKey
    let value: String

    init(_ label: LocalizedStringKey, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Text(verbatim: value).font(.system(.title2, design: .rounded).weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

/// Wrapped, non-interactive capsule chips.
struct MoreChips: View {
    let values: [String]

    var body: some View {
        MoreWrapLayout(spacing: 6) {
            ForEach(values, id: \.self) { value in
                Text(verbatim: value).font(.subheadline)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
    }
}

private struct MoreWrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 300, height: arrange(width: proposal.width ?? 300, subviews).height)
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

struct DayValue: Identifiable {
    let day: Date
    let value: Int
    var id: Date { day }

    /// "2026-10-20" entries; unreadable days are skipped.
    static func parse(_ entries: [(day: String?, events: Int?)]) -> [DayValue] {
        let format = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
        return entries.compactMap { entry in
            guard let text = entry.day, let date = try? Date(text, strategy: format) else { return nil }
            return DayValue(day: date, value: entry.events ?? 0)
        }
        .sorted { $0.day < $1.day }
    }
}

private func moreDay(_ date: Date) -> String {
    date.formatted(Date.VerbatimFormatStyle(format: "\(day: .twoDigits).\(month: .twoDigits).\(year: .padded(4))",
                                            timeZone: .gmt, calendar: Calendar(identifier: .gregorian)))
}

/// Line per day; touching the chart shows the day and value above it and marks the point.
struct DayBarChart: View {
    let days: [DayValue]
    let color: Color
    @State private var rawSelection: Date?

    private var selected: DayValue? {
        guard let raw = rawSelection else { return nil }
        return days.min { abs($0.day.timeIntervalSince(raw)) < abs($1.day.timeIntervalSince(raw)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let selected {
                    Text(verbatim: "\(moreDay(selected.day)) · ") + Text("\(selected.value.formatted()) events")
                } else {
                    Text("Touch the chart for values")
                }
            }
            .font(.caption).foregroundStyle(.secondary)
            Chart {
                ForEach(days) { item in
                    BarMark(x: .value("Day", item.day, unit: .day), y: .value("Events", item.value))
                        .foregroundStyle(color.opacity(selected == nil || selected?.id == item.id ? 1 : 0.35))
                }
            }
            .chartYScale(domain: 0...max(days.map(\.value).max() ?? 0, 1))
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel()
                }
            }
            .chartXSelection(value: $rawSelection)
            .frame(height: 140)
            .accessibilityLabel(Text("Line chart with \(days.count) values, maximum \((days.map(\.value).max() ?? 0).formatted())"))
            if let first = days.first, let last = days.last {
                HStack {
                    Text(verbatim: moreDay(first.day))
                    Spacer()
                    if last.day != first.day { Text(verbatim: moreDay(last.day)) }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
