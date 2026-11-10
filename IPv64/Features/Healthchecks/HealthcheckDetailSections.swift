import SwiftUI
import IPv64

/// `LabeledContent` that disappears for blank values (Android `InfoGroup(hideEmpty)`).
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

private func timeWithRelative(_ date: Date?) -> String? {
    guard let date = Formatters.realOrNil(date) else { return nil }
    return "\(Formatters.germanTime(date)) (\(Formatters.relative(date)))"
}

private func time(_ date: Date?) -> String? { Formatters.realOrNil(date).map(Formatters.germanTime) }

private func yesNo(_ value: Bool?) -> String? { value.map { $0 ? String(localized: "Yes") : String(localized: "No") } }

/// "Status" rows (spec B2 item 2).
struct HealthcheckStatusRows: View {
    let detail: HC2CheckDetail
    let state: HC2Check.State?

    var body: some View {
        HcInfoRow("Since", time(state?.since))
        HcInfoRow("Last check", timeWithRelative(state?.lastCheckAt))
        HcInfoRow("Last status", state?.lastStatus?.rawValue)
        HcInfoRow("Latency", state?.lastLatencyMS.map(Formatters.latency))
        HcInfoRow("Reason", state?.lastReason)
        HcInfoRow("Message", state?.lastMessage)
        HcInfoRow("Down since", time(state?.downSince), color: .ipv64Red)
        HcInfoRow("Last push", timeWithRelative(state?.lastPushAt))
        HcInfoRow("Availability 24 h", detail.availabilityPercent?.last24Hours.map(Formatters.percent))
        HcInfoRow("Availability 30 d", detail.availabilityPercent?.last30Days.map(Formatters.percent))
        HcInfoRow("Availability 1 y", detail.availabilityPercent?.lastYear.map(Formatters.percent))
    }
}

/// "Measuring points" rows.
struct HealthcheckSourceRows: View {
    let sources: [HC2CheckDetail.SourceState]

    var body: some View {
        ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
            HcDetailRow(title: source.label?.nonBlank ?? source.source ?? "–", subtitle: subtitle(source),
                        chip: StatusChip(state: Hc2StateUi.from(source.state?.rawValue)), lineLimit: 4)
        }
    }

    private func subtitle(_ source: HC2CheckDetail.SourceState) -> [String] {
        var first: [String] = []
        if let l = source.lastLatencyMS { first.append(Formatters.latency(l)) }
        if let t = source.lastCheckAt { first.append(String(localized: "checked \(Formatters.relative(t))")) }
        if let n = source.consecutiveFail, n > 0 { first.append(String(localized: "\(n) failed in a row")) }
        if let n = source.consecutiveOK, n > 0 { first.append(String(localized: "\(n) ok in a row")) }
        return [first.isEmpty ? nil : first.joined(separator: " · "),
                source.lastMessage?.nonBlank ?? source.lastReason?.nonBlank].compactMap { $0 }
    }
}

/// "Push endpoints": value + Copy (sensitive) + Share.
struct HealthcheckPushRows: View {
    let push: HC2Check.Push

    var body: some View {
        entry("Push URL", push.url)
        entry("Hub URL", push.hubURL)
        entry("Node path", push.nodePath)
    }

    @ViewBuilder
    private func entry(_ label: LocalizedStringKey, _ value: String?) -> some View {
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

/// "Configuration" rows (spec B2 item 7).
struct HealthcheckConfigRows: View {
    let detail: HC2CheckDetail
    let channels: [HC2Channel]

    private var executionText: String {
        let node = (detail.nodeName ?? "").hcTrimmed
        let locations = (detail.locations ?? []).map(\.rawValue).joined(separator: ", ")
        switch detail.execution {
        case .local: return String(localized: "Node \(node)").hcTrimmed
        case .both: return String(localized: "Online (\(locations)) + node \(node)").hcTrimmed
        default: return locations.isEmpty ? String(localized: "Online") : String(localized: "Online (\(locations))")
        }
    }

    private var channelsText: String {
        let ids = detail.channels ?? []
        if ids.isEmpty { return String(localized: "Default channels") }
        let names = ids.compactMap { id in channels.first { $0.id == id }.map(channelDisplayName) }
        return names.count == ids.count ? names.joined(separator: ", ") : String(localized: "\(ids.count) selected")
    }

    var body: some View {
        HcInfoRow("Type", detail.type.label)
        HcInfoRow("Target", detail.target)
        HcInfoRow("Interval", detail.intervalSeconds.map(Formatters.duration))
        HcInfoRow("Retry interval", detail.retryIntervalSeconds.map(Formatters.duration))
        HcInfoRow("Retries", detail.retries.map(String.init))
        HcInfoRow("Timeout", detail.timeoutSeconds.map { Formatters.duration(seconds: Int($0.rounded())) })
        HcInfoRow("Connect timeout", detail.connectTimeoutSeconds.map { Formatters.duration(seconds: Int($0.rounded())) })
        HcInfoRow("Stabilize", detail.stabilize.map(String.init))
        HcInfoRow("IP mode", detail.ipMode?.rawValue)
        HcInfoRow("Invert result", yesNo(detail.invert))
        if let nodeId = detail.nodeID?.nonBlank {
            NavigationLink(value: Route.nodeDetail(nodeId: nodeId)) {
                LabeledContent("Execution", value: executionText)
            }
        } else {
            HcInfoRow("Execution", executionText)
        }
        if (detail.locations?.count ?? 0) + (detail.nodes?.count ?? 0) > 1 { HcInfoRow("Policy", detail.policy?.rawValue) }
        HcInfoRow("Notify down", yesNo(detail.notifyDown))
        HcInfoRow("Notify up", yesNo(detail.notifyUp))
        HcInfoRow("Notify degraded", yesNo(detail.notifyDegraded))
        HcInfoRow("Critical", yesNo(detail.critical))
        HcInfoRow("Reminder", detail.repeatMinutes.map(Formatters.repeatMinutes))
        HcInfoRow("Channels", channelsText)
        HcInfoRow("Tags", (detail.tags ?? []).joined(separator: ", "))
        HcInfoRow("Group", detail.group)
        HcInfoRow("Description", detail.description)
        HcInfoRow("Created", time(detail.createdAt))
        HcInfoRow("Updated", time(detail.updatedAt))
    }
}

/// Channel `displayName`: trimmed name, else type label, else type, else `Channel #id`.
nonisolated func channelDisplayName(_ channel: HC2Channel) -> String {
    channel.name?.hcTrimmed.nonBlank ?? channel.typeLabel?.nonBlank ?? channel.type?.rawValue.nonBlank
        ?? String(localized: "Channel #\(channel.id)")
}
