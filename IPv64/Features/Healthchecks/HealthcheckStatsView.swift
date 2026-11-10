import SwiftUI
import Charts
import IPv64

nonisolated struct StatsPoint: Hashable, Sendable {
    let time: Date
    let value: Double
}

/// One latency line (a measuring point; node checks have a single one).
nonisolated struct StatsLine: Identifiable, Hashable, Sendable {
    let name: String
    let points: [StatsPoint]
    var id: String { name }
}

/// Series of an account check, grouped by source; colour order = sorted unique source names.
nonisolated func statsLines(_ stats: HC2Stats) -> [StatsLine] {
    var labels: [String: String] = [:]
    for source in stats.sources ?? [] {
        if let key = source.source { labels[key] = source.label?.nonBlank ?? key }
    }
    let valid = (stats.series ?? []).compactMap { point -> (String, StatsPoint)? in
        guard let time = point.time, let value = point.latencyAvgMS else { return nil }
        return (point.source ?? "", StatsPoint(time: time, value: value))
    }
    let keys = Set(labels.keys).union(valid.map(\.0)).sorted()
    return keys.compactMap { key in
        let points = valid.filter { $0.0 == key }.map(\.1).sorted { $0.time < $1.time }
        guard !points.isEmpty else { return nil }
        return StatsLine(name: labels[key] ?? key.nonBlank ?? "–", points: points)
    }
}

/// Series of a node check (single line).
nonisolated func statsLines(_ stats: Node64.CheckStats) -> [StatsLine] {
    let points = (stats.series ?? []).compactMap { point -> StatsPoint? in
        guard let time = Formatters.parseISO(point.time), let value = point.avgMS else { return nil }
        return StatsPoint(time: time, value: value)
    }.sorted { $0.time < $1.time }
    return points.isEmpty ? [] : [StatsLine(name: "–", points: points)]
}

private let chartPalette: [Color] = [.ipv64Blue, .ipv64Orange, .ipv64Green, .purple, .ipv64Teal, .ipv64Red, .pink, .indigo]

/// Latency line chart with touch readout (spec 02 B3), Swift Charts.
struct LatencyChart: View {
    let lines: [StatsLine]
    let dayBucket: Bool
    @State private var rawSelection: Date?

    private var times: [Date] { Array(Set(lines.flatMap { $0.points.map(\.time) })).sorted() }
    private var maxValue: Double { lines.flatMap { $0.points.map(\.value) }.max() ?? 0 }
    private var multi: Bool { lines.count >= 2 }

    private var selected: Date? {
        guard let raw = rawSelection, let first = times.first, let last = times.last else { return nil }
        let seconds = times.map(\.timeIntervalSince1970)
        let index = nearestIndex(seconds, tMin: first.timeIntervalSince1970, tMax: last.timeIntervalSince1970,
                                 fraction: last == first ? 0
                                    : (raw.timeIntervalSince1970 - first.timeIntervalSince1970)
                                        / (last.timeIntervalSince1970 - first.timeIntervalSince1970))
        return times[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Average latency (max \(Formatters.latency(maxValue)))").font(.caption).foregroundStyle(.secondary)
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
            .chartForegroundStyleScale(domain: lines.map(\.name), range: lines.indices.map { chartPalette[$0 % chartPalette.count] })
            .chartLegend(multi ? .visible : .hidden)
            .chartYScale(domain: 0...max(maxValue, 1))
            .chartXSelection(value: $rawSelection)
            .frame(height: 140)
            if let first = times.first, let last = times.last {
                HStack {
                    Text(verbatim: formatBucketTime(first, dayBucket: dayBucket))
                    Spacer()
                    if last != first { Text(verbatim: formatBucketTime(last, dayBucket: dayBucket)) }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var readout: some View {
        Group {
            if let selected {
                let values = lines.compactMap { line in
                    line.points.first { $0.time == selected }.map { multi ? "\(line.name): \(Formatters.latency($0.value))" : Formatters.latency($0.value) }
                }
                Text(verbatim: formatBucketTime(selected, dayBucket: dayBucket) + (multi ? "\n" : " · ")
                     + values.joined(separator: " · "))
            } else {
                Text("Touch the chart for values")
            }
        }
        .font(.caption)
        .lineLimit(2, reservesSpace: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Rows of the account check statistics block (spec 02 B3); goes inside a List section.
struct HealthcheckStatsRows: View {
    let stats: HC2Stats?

    var body: some View {
        if let stats {
            LabeledContent("Availability", value: Formatters.percent(stats.availabilityPercent))
            LabeledContent("Measurements", value: stats.measurements.map(Formatters.count) ?? "–")
            ForEach(Array((stats.sources ?? []).enumerated()), id: \.offset) { _, source in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: source.label?.nonBlank ?? source.source ?? "–").bold()
                    Text("Availability \(Formatters.percent(source.availabilityPercent)) · \(source.measurements ?? 0) measurements")
                    Text("Latency min \(Formatters.latency(source.latencyMS?.min)) · avg \(Formatters.latency(source.latencyMS?.avg)) · max \(Formatters.latency(source.latencyMS?.max))")
                }
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            let lines = statsLines(stats)
            if !lines.isEmpty && lines.flatMap(\.points).count >= 2 {
                LatencyChart(lines: lines, dayBucket: stats.bucket == .day)
            }
        } else {
            Text("No data").foregroundStyle(.secondary)
        }
    }
}
