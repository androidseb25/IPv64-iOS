import SwiftUI
import Charts
import IPv64

/// One latency line (a measuring point).
nonisolated struct StatsLine: Identifiable, Hashable, Sendable {
    let name: String
    let points: [Point]
    var id: String { name }

    struct Point: Hashable, Sendable {
        let time: Date
        let value: Double
    }

    /// Series grouped by source; colour order is the sorted unique source names.
    static func lines(_ stats: HC2Stats) -> [StatsLine] {
        var labels: [String: String] = [:]
        for source in stats.sources ?? [] {
            if let key = source.source { labels[key] = source.label?.nonBlank ?? key }
        }
        let valid = (stats.series ?? []).compactMap { point -> (String, Point)? in
            guard let time = point.time, let value = point.latencyAvgMS else { return nil }
            return (point.source ?? "", Point(time: time, value: value))
        }
        return Set(labels.keys).union(valid.map(\.0)).sorted().compactMap { key in
            let points = valid.filter { $0.0 == key }.map(\.1).sorted { $0.time < $1.time }
            return points.isEmpty ? nil : StatsLine(name: labels[key] ?? key.nonBlank ?? "–", points: points)
        }
    }
}

func bucketTime(_ date: Date, dayBucket: Bool) -> String {
    let gregorian = Calendar(identifier: .gregorian)
    if dayBucket {
        return date.formatted(Date.VerbatimFormatStyle(
            format: "\(day: .twoDigits).\(month: .twoDigits).\(year: .padded(4))",
            timeZone: .gmt, calendar: gregorian))
    }
    return date.formatted(Date.VerbatimFormatStyle(
        format: "\(day: .twoDigits).\(month: .twoDigits).\(year: .padded(4)) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
        timeZone: .current, calendar: gregorian))
}

/// Latency line chart with touch readout (Swift Charts).
struct LatencyChart: View {
    let lines: [StatsLine]
    let dayBucket: Bool
    @State private var rawSelection: Date?

    private static let palette: [Color] = [.blue, .orange, .green, .purple, .teal, .red, .pink, .indigo]
    private var times: [Date] { Array(Set(lines.flatMap { $0.points.map(\.time) })).sorted() }
    private var maxValue: Double { lines.flatMap { $0.points.map(\.value) }.max() ?? 0 }
    private var multi: Bool { lines.count >= 2 }

    private var selected: Date? {
        guard let raw = rawSelection else { return nil }
        return times.min { abs($0.timeIntervalSince(raw)) < abs($1.timeIntervalSince(raw)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Average latency (max \(HcFormat.latency(maxValue)))").font(.caption).foregroundStyle(.secondary)
            readout
            Chart {
                ForEach(lines) { line in
                    ForEach(Array(line.points.enumerated()), id: \.offset) { _, p in
                        LineMark(x: .value("Time", p.time), y: .value("Latency", p.value))
                            .foregroundStyle(by: .value("Source", line.name))
                        if line.points.count == 1 {
                            PointMark(x: .value("Time", p.time), y: .value("Latency", p.value))
                                .foregroundStyle(by: .value("Source", line.name))
                        }
                    }
                }
                if let selected {
                    RuleMark(x: .value("Selected", selected)).foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .chartForegroundStyleScale(domain: lines.map(\.name),
                                       range: lines.indices.map { Self.palette[$0 % Self.palette.count] })
            .chartLegend(multi ? .visible : .hidden)
            .chartYScale(domain: 0...max(maxValue, 1))
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel()
                }
            }
            .chartXSelection(value: $rawSelection)
            .frame(height: 140)
            if let first = times.first, let last = times.last {
                HStack {
                    Text(verbatim: bucketTime(first, dayBucket: dayBucket))
                    Spacer()
                    if last != first { Text(verbatim: bucketTime(last, dayBucket: dayBucket)) }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var readout: some View {
        Group {
            if let selected {
                let values = lines.compactMap { line in
                    line.points.first { $0.time == selected }.map {
                        multi ? "\(line.name): \(HcFormat.latency($0.value))" : HcFormat.latency($0.value)
                    }
                }
                Text(verbatim: bucketTime(selected, dayBucket: dayBucket) + (multi ? "\n" : " · ") + values.joined(separator: " · "))
            } else {
                Text("Touch the chart for values")
            }
        }
        .font(.caption)
        .lineLimit(2, reservesSpace: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Statistics block: large availability, latency chart, key figures; goes inside a List section.
struct HealthcheckStatsRows: View {
    let stats: HC2Stats

    private var sources: [HC2Stats.Source] { stats.sources ?? [] }

    private func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: HcFormat.percent(stats.availabilityPercent))
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Availability").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        let lines = StatsLine.lines(stats)
        if lines.flatMap(\.points).count >= 2 {
            LatencyChart(lines: lines, dayBucket: stats.bucket == .day)
        }
        if let total = stats.measurements {
            LabeledContent("Checks", value: total.formatted())
            if let availability = stats.availabilityPercent {
                LabeledContent("Failed checks", value: max(0, Int((Double(total) * (1 - availability / 100)).rounded())).formatted())
            }
        }
        LabeledContent("Average latency", value: HcFormat.latency(mean(sources.compactMap { $0.latencyMS?.avg })))
        LabeledContent("Maximum latency", value: HcFormat.latency(sources.compactMap { $0.latencyMS?.max }.max()))
    }
}
