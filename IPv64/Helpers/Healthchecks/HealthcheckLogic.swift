import SwiftUI
import IPv64

// Healthchecks 2.0 list logic (ported from Android 2.1.0: Hc2CheckUi.kt, HealthcheckView.kt).

nonisolated extension HC2CheckType {
    /// Readable type name.
    var label: String {
        switch self {
        case .http: "HTTP(S)"
        case .keyword: "Keyword"
        case .json: "JSON"
        case .dns: "DNS"
        case .icmp: "Ping (ICMP)"
        case .tcp: "TCP"
        case .port: "Port"
        case .cert: "Certificate"
        case .push: "Push"
        case .whois: "WHOIS"
        default: "Unknown"
        }
    }
}

/// Displayed state of a check; `paused` wins over the measured state.
nonisolated enum Hc2StateUi: Sendable {
    case up, down, degraded, flapping, paused, pending

    static func from(_ check: HC2Check) -> Hc2StateUi { from(state: check.state?.state, paused: check.paused) }

    var label: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .degraded: "Degraded"
        case .flapping: "Flapping"
        case .paused: "Paused"
        case .pending: "Pending"
        }
    }

    var color: Color {
        switch self {
        case .up: .green
        case .down: .red
        case .degraded, .flapping: .orange
        case .paused: .teal
        case .pending: .gray
        }
    }
}

nonisolated enum HcStatusFilter: CaseIterable, Hashable, Sendable {
    case all, up, degraded, down, paused

    var label: String {
        switch self {
        case .all: "All"
        case .up: "Up"
        case .degraded: "Degraded"
        case .down: "Down"
        case .paused: "Paused"
        }
    }

    func matches(_ state: Hc2StateUi) -> Bool {
        switch (self, state) {
        case (.all, _), (.up, .up), (.degraded, .degraded), (.degraded, .flapping), (.down, .down), (.paused, .paused):
            true
        default:
            false
        }
    }
}

/// Where a check runs; the filter is only offered when some check runs on a node.
nonisolated enum HcExecFilter: CaseIterable, Hashable, Sendable {
    case all, online, node, both

    var label: String {
        switch self {
        case .all: "All"
        case .online: "Online"
        case .node: "Node"
        case .both: "Both"
        }
    }

    func matches(_ execution: HC2Execution?) -> Bool {
        switch self {
        case .all: true
        case .online: (execution ?? .online) == .online
        case .node: execution == .local
        case .both: execution == .both
        }
    }
}
