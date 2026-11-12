import SwiftUI
import IPv64

// Building blocks of the node check detail; the look is shared with the account check detail.

struct NodeCheckStatusRows: View {
    let check: Node64.Check

    static func hasContent(_ check: Node64.Check) -> Bool {
        guard let s = check.state else { return false }
        return [s.since, s.lastCheckAt, s.lastStatus, s.lastReason, s.lastMessage, s.downSince, s.lastPushAt]
            .contains { $0?.nonBlank != nil } || s.lastLatencyMS != nil
    }

    var body: some View {
        let s = check.state
        HcInfoRow("Since", HcFormat.time(nodeDate(s?.since)))
        HcInfoRow("Last check", HcFormat.timeWithRelative(nodeDate(s?.lastCheckAt)))
        HcInfoRow("Last status", s?.lastStatus)
        HcInfoRow("Latency", s?.lastLatencyMS.map { HcFormat.latency($0) })
        HcInfoRow("Reason", s?.lastReason)
        HcInfoRow("Message", s?.lastMessage)
        HcInfoRow("Down since", HcFormat.time(nodeDate(s?.downSince)), color: .red)
        HcInfoRow("Last push", HcFormat.timeWithRelative(nodeDate(s?.lastPushAt)))
    }
}

struct NodeCheckConfigRows: View {
    let check: Node64.Check

    var body: some View {
        HcInfoRow("Type", check.type?.label)
        HcInfoRow("Target", check.target)
        HcInfoRow("Interval", check.intervalSeconds.map { HcFormat.duration(seconds: $0) })
        HcInfoRow("Retry interval", check.retryIntervalSeconds.map { HcFormat.duration(seconds: $0) })
        HcInfoRow("Retries", check.retries.map(String.init))
        HcInfoRow("Timeout", check.timeoutSeconds.map { HcFormat.seconds($0) })
        HcInfoRow("Connect timeout", check.connectTimeoutSeconds.map { HcFormat.seconds($0) })
        HcInfoRow("Stabilize", check.stabilize.map(String.init))
        HcInfoRow("IP mode", check.ipMode?.rawValue)
        HcInfoRow("Invert result", HcFormat.yesNo(check.invert))
        HcInfoRow("Notify down", HcFormat.yesNo(check.notifyDown))
        HcInfoRow("Notify up", HcFormat.yesNo(check.notifyUp))
        HcInfoRow("Notify degraded", HcFormat.yesNo(check.notifyDegraded))
        HcInfoRow("Critical", HcFormat.yesNo(check.critical))
        HcInfoRow("Reminder", check.repeatMinutes.map(HcFormat.repeatMinutes))
        HcInfoRow("Tags", (check.tags ?? []).joined(separator: ", "))
        HcInfoRow("Group", check.group)
        HcInfoRow("Description", check.description)
        HcInfoRow("Created", HcFormat.time(nodeDate(check.createdAt)))
        HcInfoRow("Updated", HcFormat.time(nodeDate(check.updatedAt)))
    }
}

/// Statistics block like the account check: large availability, latency chart, key figures.
struct NodeCheckStatsRows: View {
    let stats: Node64.CheckStats

    private var line: [StatsLine] {
        let points = (stats.series ?? []).compactMap { point -> StatsLine.Point? in
            guard let time = nodeDate(point.time), let value = point.avgMS else { return nil }
            return StatsLine.Point(time: time, value: value)
        }.sorted { $0.time < $1.time }
        return points.isEmpty ? [] : [StatsLine(name: "Latency", points: points)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: HcFormat.percent(stats.upPercent))
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Availability").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        let lines = line
        if lines.flatMap(\.points).count >= 2 {
            LatencyChart(lines: lines, dayBucket: (stats.bucketSeconds ?? 0) >= 86_400)
        }
        if let total = stats.count {
            LabeledContent("Checks", value: total.formatted())
            if let up = stats.upCount { LabeledContent("Failed checks", value: max(0, total - up).formatted()) }
        }
        LabeledContent("Average latency", value: HcFormat.latency(stats.avgMS))
        LabeledContent("Maximum latency", value: HcFormat.latency(stats.maxMS))
    }
}

struct NodeCheckEventRow: View {
    let event: Node64.CheckEvent

    private var state: Hc2StateUi { HcFormat.eventState(kind: event.kind, to: event.to) }

    private var lines: [String] {
        var lines: [String] = []
        if event.from?.nonBlank != nil || event.to?.nonBlank != nil {
            lines.append("\(event.from?.nonBlank ?? "–") → \(event.to?.nonBlank ?? "–")")
        }
        var meta: [String] = []
        if let seconds = event.durationSeconds { meta.append(String(localized: "after \(HcFormat.duration(seconds: seconds))")) }
        if let flaps = event.flaps, flaps > 0 { meta.append(String(localized: "\(flaps) flaps")) }
        if event.silent == true { meta.append(String(localized: "silent")) }
        if !meta.isEmpty { lines.append(meta.joined(separator: " · ")) }
        if let text = event.message?.nonBlank ?? event.reason?.nonBlank { lines.append(text) }
        if let time = HcFormat.time(nodeDate(event.time)) { lines.append(time) }
        return lines
    }

    var body: some View {
        HcDetailRow(title: HcFormat.eventTitle(kind: event.kind, fallback: state.label), subtitle: lines) {
            HealthcheckStateTag(state: state)
        }
    }
}

/// Pushed list of the incidents of a node check.
struct NodeCheckIncidentsView: View {
    let incidents: [Node64.CheckIncident]

    var body: some View {
        if #available(iOS 26.0, *) {
            list.setColorGradient(.orange)
        } else {
            list
        }
    }

    private var list: some View {
        List(incidents) { NodeCheckIncidentRow(incident: $0) }
            .navigationTitle("Incidents")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if incidents.isEmpty { ContentUnavailableView("No incidents", systemImage: "checkmark.circle") }
            }
    }
}

struct NodeCheckIncidentRow: View {
    let incident: Node64.CheckIncident

    private var started: Date? { HcFormat.real(nodeDate(incident.startedAt)) }

    private var subtitle: String? {
        var parts: [String] = []
        if let started {
            let end = HcFormat.real(nodeDate(incident.endedAt)) ?? (incident.open == true ? Date() : nil)
            if let end, end > started { parts.append(HcFormat.duration(seconds: Int(end.timeIntervalSince(started)))) }
        }
        if let text = incident.message?.nonBlank ?? incident.reason?.nonBlank { parts.append(text) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        let open = incident.open == true
        HStack(spacing: 12) {
            Image(systemName: open ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(open ? .red : .green)
                .font(.title3)
                .accessibilityLabel(open ? "Open incident" : "Resolved incident")
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: HcFormat.time(started) ?? "–")
                if let subtitle {
                    Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                }
            }
            Spacer(minLength: 8)
            if let started {
                Text(started.formatted(.relative(presentation: .named))).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
