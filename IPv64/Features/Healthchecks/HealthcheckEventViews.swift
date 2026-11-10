import SwiftUI
import IPv64

/// Bar of the latest states, newest on the right (spec 02 B2 `StatusPillsBar`). `states` newest first.
struct StatusPillsBar: View {
    let states: [Hc2StateUi]
    let noun: String
    private let limit = 30

    var body: some View {
        let shown = Array(states.prefix(limit).reversed())
        HStack(spacing: 3) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, state in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(state.color)
                    .frame(maxWidth: 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 32)
        .accessibilityElement()
        .accessibilityLabel(summary(shown))
    }

    private func summary(_ shown: [Hc2StateUi]) -> String {
        guard let latest = shown.last else { return "No \(noun)" }
        return "Last \(shown.count) \(noun), latest: \(latest.text.lowercased())"
    }
}

/// Title, multi-line subtitle and a state chip (events, incidents, sources).
struct HcDetailRow: View {
    let title: String
    var subtitle: [String] = []
    let chip: StatusChip
    var lineLimit = 6

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                if !subtitle.isEmpty {
                    Text(verbatim: subtitle.joined(separator: "\n"))
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(lineLimit)
                }
            }
            Spacer(minLength: 8)
            chip
        }
        .accessibilityElement(children: .combine)
    }
}

/// Account check event row (spec B2 `HealthcheckEventItemView`).
struct HealthcheckEventRow: View {
    let event: HC2Event

    private var state: Hc2StateUi { healthcheckEventState(kind: event.kind?.rawValue, to: event.toState) }

    private var lines: [String] {
        var lines: [String] = []
        if event.fromState?.nonBlank != nil || event.toState?.nonBlank != nil {
            lines.append("\(event.fromState?.nonBlank ?? "–") → \(event.toState?.nonBlank ?? "–")")
        }
        var meta: [String] = []
        if let label = event.sourceLabel?.nonBlank { meta.append(label) }
        if let seconds = event.durationSeconds { meta.append(String(localized: "after \(Formatters.duration(seconds: seconds))")) }
        if let flaps = event.flaps, flaps > 0 { meta.append(String(localized: "\(flaps) flaps")) }
        if event.silent == true { meta.append(String(localized: "silent")) }
        if !meta.isEmpty { lines.append(meta.joined(separator: " · ")) }
        if let text = event.message?.nonBlank ?? event.reason?.nonBlank { lines.append(text) }
        if let time = event.time { lines.append(Formatters.germanTime(time)) }
        return lines
    }

    var body: some View {
        HcDetailRow(title: healthcheckEventTitle(kind: event.kind?.rawValue, fallback: state.text),
                    subtitle: lines, chip: StatusChip(state: state))
    }
}

extension Hc2StateUi {
    /// Plain localized label (for string interpolation).
    var text: String {
        switch self {
        case .up: String(localized: "Up")
        case .down: String(localized: "Down")
        case .degraded: String(localized: "Degraded")
        case .flapping: String(localized: "Flapping")
        case .paused: String(localized: "Paused")
        case .pending: String(localized: "Pending")
        case .unknown: String(localized: "Unknown")
        }
    }
}

/// Account check incident row.
struct HealthcheckIncidentRow: View {
    let incident: HC2Incident

    private var lines: [String] {
        var lines: [String] = []
        if let t = incident.startedAt { lines.append(String(localized: "Started \(Formatters.germanTime(t))")) }
        if let t = incident.endedAt { lines.append(String(localized: "Ended \(Formatters.germanTime(t))")) }
        if let s = incident.durationSeconds { lines.append(String(localized: "Duration \(Formatters.duration(seconds: s))")) }
        if let text = incident.message?.nonBlank ?? incident.reason?.nonBlank { lines.append(text) }
        if let sources = incident.sources, !sources.isEmpty { lines.append(sources.joined(separator: ", ")) }
        return lines
    }

    var body: some View {
        let open = incident.status == .open
        HcDetailRow(
            title: open ? String(localized: "Open incident") : String(localized: "Resolved incident"),
            subtitle: lines,
            chip: open ? StatusChip("Open", color: .ipv64Red) : StatusChip("Resolved", color: .ipv64Green))
    }
}

/// Node check event row (timestamps are strings).
struct NodeCheckEventRow: View {
    let event: Node64.CheckEvent

    private var state: Hc2StateUi { healthcheckEventState(kind: event.kind, to: event.to) }

    private var lines: [String] {
        var lines: [String] = []
        if event.from?.nonBlank != nil || event.to?.nonBlank != nil {
            lines.append("\(event.from?.nonBlank ?? "–") → \(event.to?.nonBlank ?? "–")")
        }
        var meta: [String] = []
        if let s = event.durationSeconds { meta.append(String(localized: "after \(Formatters.duration(seconds: s))")) }
        if let n = event.flaps, n > 0 { meta.append(String(localized: "\(n) flaps")) }
        if event.silent == true { meta.append(String(localized: "silent")) }
        if !meta.isEmpty { lines.append(meta.joined(separator: " · ")) }
        if let text = event.message?.nonBlank ?? event.reason?.nonBlank { lines.append(text) }
        if let t = Formatters.parseISO(event.time) { lines.append(Formatters.germanTime(t)) }
        return lines
    }

    var body: some View {
        HcDetailRow(title: healthcheckEventTitle(kind: event.kind, fallback: state.text),
                    subtitle: lines, chip: StatusChip(state: state))
    }
}

/// Node check incident row.
struct NodeCheckIncidentRow: View {
    let incident: Node64.CheckIncident

    private var lines: [String] {
        var lines: [String] = []
        if let t = Formatters.parseISO(incident.startedAt) { lines.append(String(localized: "Started \(Formatters.germanTime(t))")) }
        if let t = Formatters.parseISO(incident.endedAt) { lines.append(String(localized: "Ended \(Formatters.germanTime(t))")) }
        if let text = incident.message?.nonBlank ?? incident.reason?.nonBlank { lines.append(text) }
        return lines
    }

    var body: some View {
        let open = incident.open == true
        HcDetailRow(
            title: open ? String(localized: "Open incident") : String(localized: "Resolved incident"),
            subtitle: lines,
            chip: open ? StatusChip("Open", color: .ipv64Red) : StatusChip("Resolved", color: .ipv64Green))
    }
}
