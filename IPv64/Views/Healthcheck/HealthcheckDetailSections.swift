import SwiftUI
import IPv64

/// `LabeledContent` that disappears for blank values.
struct HcInfoRow: View {
    let label: LocalizedStringKey
    let value: String?
    var color: Color?

    init(_ label: LocalizedStringKey, _ value: String?, color: Color? = nil) {
        self.label = label
        self.value = value?.nonBlank
        self.color = color
    }

    var body: some View {
        if let value {
            LabeledContent(label) { Text(verbatim: value).foregroundStyle(color ?? .primary) }
        }
    }
}

struct HealthcheckStatusRows: View {
    let detail: HC2CheckDetail
    let state: HC2Check.State?

    var body: some View {
        HcInfoRow("Since", HcFormat.time(state?.since))
        HcInfoRow("Last check", HcFormat.timeWithRelative(state?.lastCheckAt))
        HcInfoRow("Last status", state?.lastStatus?.rawValue)
        HcInfoRow("Latency", state?.lastLatencyMS.map { HcFormat.latency($0) })
        HcInfoRow("Reason", state?.lastReason)
        HcInfoRow("Message", state?.lastMessage)
        HcInfoRow("Down since", HcFormat.time(state?.downSince), color: .red)
        HcInfoRow("Last push", HcFormat.timeWithRelative(state?.lastPushAt))
        HcInfoRow("Availability 24 h", detail.availabilityPercent?.last24Hours.map { HcFormat.percent($0) })
        HcInfoRow("Availability 30 d", detail.availabilityPercent?.last30Days.map { HcFormat.percent($0) })
        HcInfoRow("Availability 1 y", detail.availabilityPercent?.lastYear.map { HcFormat.percent($0) })
    }
}

/// Title, multi-line subtitle and a state tag (events, incidents, measuring points).
struct HcDetailRow<Tag: View>: View {
    let title: String
    var subtitle: [String] = []
    @ViewBuilder var tag: Tag

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                if !subtitle.isEmpty {
                    Text(verbatim: subtitle.joined(separator: "\n")).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            tag
        }
        .accessibilityElement(children: .combine)
    }
}

struct HealthcheckSourceRows: View {
    let sources: [HC2CheckDetail.SourceState]

    var body: some View {
        ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
            HcDetailRow(title: source.label?.nonBlank ?? source.source ?? "–", subtitle: subtitle(source)) {
                HealthcheckStateTag(state: .from(state: source.state, paused: false))
            }
        }
    }

    private func subtitle(_ source: HC2CheckDetail.SourceState) -> [String] {
        var first: [String] = []
        if let value = source.lastLatencyMS { first.append(HcFormat.latency(value)) }
        if let date = HcFormat.real(source.lastCheckAt) {
            first.append(String(localized: "checked \(date.formatted(.relative(presentation: .named)))"))
        }
        if let n = source.consecutiveFail, n > 0 { first.append(String(localized: "\(n) failed in a row")) }
        if let n = source.consecutiveOK, n > 0 { first.append(String(localized: "\(n) ok in a row")) }
        return [first.isEmpty ? nil : first.joined(separator: " · "),
                source.lastMessage?.nonBlank ?? source.lastReason?.nonBlank].compactMap { $0 }
    }
}

/// Push endpoints: value, copy (sensitive) and share.
struct HealthcheckPushRows: View {
    let push: HC2Check.Push

    var body: some View {
        entry("Push URL", push.url)
        entry("Hub URL", push.hubURL)
        entry("Node path", push.nodePath)
    }

    @ViewBuilder private func entry(_ label: LocalizedStringKey, _ value: String?) -> some View {
        if let value = value?.nonBlank {
            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(.subheadline).foregroundStyle(.secondary)
                Text(verbatim: value).font(.callout.monospaced()).textSelection(.enabled)
                HStack(spacing: 16) {
                    Button("Copy", systemImage: "doc.on.doc") { Clipboard.copy(value, sensitive: true) }
                    ShareLink(item: value) { Label("Share", systemImage: "square.and.arrow.up") }
                }
                .buttonStyle(.borderless)
                .font(.subheadline)
            }
        }
    }
}

struct HealthcheckConfigRows: View {
    let detail: HC2CheckDetail
    let channels: [HC2Channel]

    private var executionText: String {
        let node = (detail.nodeName ?? "").trimmingCharacters(in: .whitespaces)
        let locations = (detail.locations ?? []).map(\.rawValue).joined(separator: ", ")
        switch detail.execution {
        case .local: return String(localized: "Node \(node)").trimmingCharacters(in: .whitespaces)
        case .both: return String(localized: "Online (\(locations)) + node \(node)").trimmingCharacters(in: .whitespaces)
        default: return locations.isEmpty ? String(localized: "Online") : String(localized: "Online (\(locations))")
        }
    }

    private var channelsText: String {
        let ids = detail.channels ?? []
        if ids.isEmpty { return String(localized: "Default channels") }
        let names = ids.compactMap { id in channels.first { $0.id == id }.map(HcFormat.channelName) }
        return names.count == ids.count ? names.joined(separator: ", ") : String(localized: "\(ids.count) selected")
    }

    var body: some View {
        HcInfoRow("Type", detail.type?.label)
        HcInfoRow("Target", detail.target)
        HcInfoRow("Interval", detail.intervalSeconds.map { HcFormat.duration(seconds: $0) })
        HcInfoRow("Retry interval", detail.retryIntervalSeconds.map { HcFormat.duration(seconds: $0) })
        HcInfoRow("Retries", detail.retries.map(String.init))
        HcInfoRow("Timeout", detail.timeoutSeconds.map { HcFormat.seconds($0) })
        HcInfoRow("Connect timeout", detail.connectTimeoutSeconds.map { HcFormat.seconds($0) })
        HcInfoRow("Stabilize", detail.stabilize.map(String.init))
        HcInfoRow("IP mode", detail.ipMode?.rawValue)
        HcInfoRow("Invert result", HcFormat.yesNo(detail.invert))
        HcInfoRow("Execution", executionText)
        if (detail.locations?.count ?? 0) + (detail.nodes?.count ?? 0) > 1 { HcInfoRow("Policy", detail.policy?.rawValue) }
        HcInfoRow("Notify down", HcFormat.yesNo(detail.notifyDown))
        HcInfoRow("Notify up", HcFormat.yesNo(detail.notifyUp))
        HcInfoRow("Notify degraded", HcFormat.yesNo(detail.notifyDegraded))
        HcInfoRow("Critical", HcFormat.yesNo(detail.critical))
        HcInfoRow("Reminder", detail.repeatMinutes.map(HcFormat.repeatMinutes))
        HcInfoRow("Channels", channelsText)
        HcInfoRow("Tags", (detail.tags ?? []).joined(separator: ", "))
        HcInfoRow("Group", detail.group)
        HcInfoRow("Description", detail.description)
        HcInfoRow("Created", HcFormat.time(detail.createdAt))
        HcInfoRow("Updated", HcFormat.time(detail.updatedAt))
    }
}

/// Bar of the latest states, newest on the right. `states` newest first.
struct StatusPillsBar: View {
    let states: [Hc2StateUi]
    let noun: String

    var body: some View {
        let shown = Array(states.prefix(30).reversed())
        HStack(spacing: 3) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, state in
                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(state.color).frame(maxWidth: 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 32)
        .accessibilityElement()
        .accessibilityLabel(shown.last.map { "Last \(shown.count) \(noun), latest: \($0.label.lowercased())" } ?? "No \(noun)")
    }
}

struct HealthcheckEventRow: View {
    let event: HC2Event

    private var state: Hc2StateUi { HcFormat.eventState(kind: event.kind?.rawValue, to: event.toState) }

    private var lines: [String] {
        var lines: [String] = []
        if event.fromState?.nonBlank != nil || event.toState?.nonBlank != nil {
            lines.append("\(event.fromState?.nonBlank ?? "–") → \(event.toState?.nonBlank ?? "–")")
        }
        var meta: [String] = []
        if let label = event.sourceLabel?.nonBlank { meta.append(label) }
        if let seconds = event.durationSeconds { meta.append(String(localized: "after \(HcFormat.duration(seconds: seconds))")) }
        if let flaps = event.flaps, flaps > 0 { meta.append(String(localized: "\(flaps) flaps")) }
        if event.silent == true { meta.append(String(localized: "silent")) }
        if !meta.isEmpty { lines.append(meta.joined(separator: " · ")) }
        if let text = event.message?.nonBlank ?? event.reason?.nonBlank { lines.append(text) }
        if let time = HcFormat.time(event.time) { lines.append(time) }
        return lines
    }

    var body: some View {
        HcDetailRow(title: HcFormat.eventTitle(kind: event.kind?.rawValue, fallback: state.label), subtitle: lines) {
            HealthcheckStateTag(state: state)
        }
    }
}

struct HealthcheckIncidentRow: View {
    let incident: HC2Incident

    private var lines: [String] {
        var lines: [String] = []
        if let t = HcFormat.time(incident.startedAt) { lines.append(String(localized: "Started \(t)")) }
        if let t = HcFormat.time(incident.endedAt) { lines.append(String(localized: "Ended \(t)")) }
        if let s = incident.durationSeconds { lines.append(String(localized: "Duration \(HcFormat.duration(seconds: s))")) }
        if let text = incident.message?.nonBlank ?? incident.reason?.nonBlank { lines.append(text) }
        if let sources = incident.sources, !sources.isEmpty { lines.append(sources.joined(separator: ", ")) }
        return lines
    }

    var body: some View {
        let open = incident.status == .open
        HcDetailRow(title: open ? String(localized: "Open incident") : String(localized: "Resolved incident"),
                    subtitle: lines) {
            HealthcheckTag(text: open ? "Open" : "Resolved", color: open ? .red : .green)
        }
    }
}
