import SwiftUI
import Charts
import IPv64

/// Line chart of a Monitor64 host chart (average values, one line per series) with touch readout of time and values.
struct Monitor64ChartView: View {
    let title: String
    let unit: String
    /// Top of the y axis.
    let top: Double
    let lines: [StatsLine]
    @State private var rawSelection: Date?

    private static let palette: [Color] = [.blue, .orange, .green, .purple, .teal, .red, .pink, .indigo]
    private var times: [Date] { Array(Set(lines.flatMap { $0.points.map(\.time) })).sorted() }
    private var multi: Bool { lines.count >= 2 }

    private var selected: Date? {
        guard let raw = rawSelection else { return nil }
        return times.min { abs($0.timeIntervalSince(raw)) < abs($1.timeIntervalSince(raw)) }
    }

    private func value(_ v: Double) -> String {
        (v.formatted(.number.precision(.fractionLength(0...1)))) + (unit.isEmpty ? "" : " \(unit)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "\(title) (max \(value(top)))").font(.subheadline.weight(.semibold))
            readout
            Chart {
                ForEach(lines) { line in
                    ForEach(Array(line.points.enumerated()), id: \.offset) { _, p in
                        LineMark(x: .value("Time", p.time), y: .value("Value", p.value))
                            .foregroundStyle(by: .value("Series", line.name))
                    }
                }
                if let selected {
                    RuleMark(x: .value("Selected", selected)).foregroundStyle(.secondary.opacity(0.5))
                    // A dot on each line at the touched time.
                    ForEach(lines) { line in
                        if let p = line.points.min(by: { abs($0.time.timeIntervalSince(selected)) < abs($1.time.timeIntervalSince(selected)) }) {
                            PointMark(x: .value("Time", p.time), y: .value("Value", p.value))
                                .foregroundStyle(by: .value("Series", line.name))
                                .symbolSize(70)
                        }
                    }
                }
            }
            .chartForegroundStyleScale(domain: lines.map(\.name),
                                       range: lines.indices.map { Self.palette[$0 % Self.palette.count] })
            .chartLegend(multi ? .visible : .hidden)
            .chartYScale(domain: 0...max(top, 1))
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel()
                }
            }
            .chartXSelection(value: $rawSelection)
            .frame(height: 120)
            if let first = times.first, let last = times.last {
                HStack {
                    Text(verbatim: bucketTime(first, dayBucket: false))
                    Spacer()
                    if last != first { Text(verbatim: bucketTime(last, dayBucket: false)) }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var readout: some View {
        Group {
            if let selected {
                let values = lines.compactMap { line in
                    line.points.min { abs($0.time.timeIntervalSince(selected)) < abs($1.time.timeIntervalSince(selected)) }
                        .map { multi ? "\(line.name) \(value($0.value))" : value($0.value) }
                }
                Text(verbatim: bucketTime(selected, dayBucket: false) + (multi ? "\n" : " · ") + values.joined(separator: " · "))
            } else {
                Text("Touch the chart for values")
            }
        }
        .font(.caption)
        .lineLimit(2, reservesSpace: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
