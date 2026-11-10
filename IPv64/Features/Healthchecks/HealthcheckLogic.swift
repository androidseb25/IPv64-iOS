import SwiftUI
import IPv64

// Pure healthcheck logic (spec 02 B0, B1, B3–B5; Android Hc2CheckUi.kt, Hc2Support.kt, HealthcheckFormView.kt,
// HealthcheckStatsView.kt). Everything here is nonisolated so tests can call it.

// MARK: - Type labels

nonisolated extension HC2CheckType {
    /// Readable type name (Android `Hc2CheckType?.label`).
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
        case .docker: "Docker"
        case .whois: "WHOIS"
        default: "Unknown"
        }
    }

    /// Placeholder of the target field.
    var targetHint: String {
        switch self {
        case .http, .keyword, .json: "https://example.com/health"
        case .dns, .whois: "example.com"
        case .icmp: "example.com or IP address"
        case .tcp, .port: "host:port"
        case .cert: "example.com or host:port"
        case .docker: "Container name"
        default: ""
        }
    }

    /// Docker always needs a node.
    var creatableOnline: Bool { self != .docker }
}

nonisolated extension Node64.CheckType {
    /// Same strings as the cloud types.
    var label: String { HC2CheckType(rawValue: rawValue).label }
}

nonisolated extension Optional where Wrapped == HC2CheckType {
    var label: String { self?.label ?? "Unknown" }
}

/// Order of the type picker when creating a check.
nonisolated let healthcheckCreateTypes: [HC2CheckType] = [
    .http, .keyword, .json, .dns, .icmp, .tcp, .port, .cert, .push, .whois, .docker,
]

/// Node64 type order (spec B7).
nonisolated let nodeCheckTypes: [Node64.CheckType] = [
    .http, .keyword, .json, .dns, .icmp, .tcp, .port, .cert, .whois, .push, .docker,
]

nonisolated let healthcheckRepeatOptions: [Int?] = [nil, 0, 5, 10, 15, 30, 60, 120, 360, 720, 1440]

// MARK: - Filters (spec B1)

nonisolated enum HcStatusFilter: CaseIterable, Hashable, Sendable {
    case all, up, degraded, down, paused

    var label: String {
        switch self {
        case .all: String(localized: "All")
        case .up: String(localized: "Up")
        case .degraded: String(localized: "Degraded")
        case .down: String(localized: "Down")
        case .paused: String(localized: "Paused")
        }
    }

    /// Account checks (`Hc2StateUi` mapping, paused overrides).
    func matches(state: String?, paused: Bool?) -> Bool {
        switch (self, Hc2StateUi.from(state, paused: paused)) {
        case (.all, _), (.up, .up), (.degraded, .degraded), (.degraded, .flapping), (.down, .down), (.paused, .paused):
            return true
        default:
            return false
        }
    }

    /// Node checks: pending/stabilizing/dependent only match `all`.
    func matchesNode(state: String?, paused: Bool?) -> Bool {
        let st = paused == true ? "paused" : state?.lowercased()
        switch self {
        case .all: return true
        case .up: return st == "up"
        case .degraded: return st == "degraded" || st == "flapping"
        case .down: return st == "down"
        case .paused: return st == "paused"
        }
    }
}

nonisolated enum HcExecFilter: CaseIterable, Hashable, Sendable {
    case all, online, node, both

    var label: String {
        switch self {
        case .all: String(localized: "All")
        case .online: String(localized: "Online")
        case .node: String(localized: "Node")
        case .both: String(localized: "Both")
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

/// Search: empty query matches everything; else name, target or type label contains it.
nonisolated func healthcheckMatchesSearch(_ query: String, name: String?, target: String?, typeLabel: String?) -> Bool {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if q.isEmpty { return true }
    return [name, target, typeLabel].contains { $0?.lowercased().contains(q) == true }
}

/// Account check list: status && exec && search.
nonisolated func healthcheckVisible(
    _ checks: [HC2Check], status: HcStatusFilter, exec: HcExecFilter, query: String
) -> [HC2Check] {
    checks.filter {
        status.matches(state: $0.state?.state?.rawValue, paused: $0.paused)
            && exec.matches($0.execution)
            && healthcheckMatchesSearch(query, name: $0.name, target: $0.target, typeLabel: $0.type.label)
    }
}

/// Node group rows: owner, status and search (name/target only), sorted by name.
nonisolated func nodeChecksVisible(_ checks: [Node64.Check], status: HcStatusFilter, query: String) -> [Node64.Check] {
    checks.filter {
        isNodeOwned($0.owner)
            && status.matchesNode(state: $0.state?.state?.rawValue, paused: $0.paused)
            && healthcheckMatchesSearch(query, name: $0.name, target: $0.target, typeLabel: nil)
    }
    .sorted { ($0.name ?? "").lowercased() < ($1.name ?? "").lowercased() }
}

/// `owner != online && owner != other` (nil / "self" / unknown → node-owned).
nonisolated func isNodeOwned(_ owner: Node64.CheckOwner?) -> Bool {
    owner != .online && owner != .other
}

/// Account list hides checks owned by a connected node.
nonisolated func accountChecks(_ all: [HC2Check], hiddenTokens: Set<String>) -> [HC2Check] {
    all.filter { !hiddenTokens.contains($0.token) }
        .sorted { ($0.name ?? "").lowercased() < ($1.name ?? "").lowercased() }
}

nonisolated func healthcheckStatusCount(_ checks: [HC2Check], _ filter: HcStatusFilter) -> Int {
    checks.filter { filter.matches(state: $0.state?.state?.rawValue, paused: $0.paused) }.count
}

/// Exec chips are shown only while a filter is active or any check runs on a node.
nonisolated func showsExecFilter(_ checks: [HC2Check], current: HcExecFilter) -> Bool {
    current != .all || checks.contains { !HcExecFilter.online.matches($0.execution) }
}

// MARK: - Node module state (spec B1.3)

nonisolated enum NodeChecksModule: Sendable { case on, off, missing }

nonisolated func nodeChecksModule(_ modules: [Node64.ModuleStatus]?) -> NodeChecksModule {
    guard let modules, !modules.isEmpty else { return .on }
    guard let module = modules.first(where: { ["checks", "healthchecks"].contains($0.name.lowercased()) }) else { return .missing }
    return module.enabled == false ? .off : .on
}

// MARK: - Row texts

/// Execution label of an account check row.
nonisolated func healthcheckExecutionLabel(_ execution: HC2Execution?, nodeName: String?) -> String? {
    let node = nodeName?.nonBlank ?? "Node"
    switch execution {
    case .local: return node
    case .both: return "Online + \(node)"
    default: return nil
    }
}

/// Node64 state chip label ("Up", "Down", … "–").
nonisolated func nodeCheckStateLabel(_ state: Node64.CheckStateKind?) -> String {
    guard let raw = state?.rawValue, let first = raw.first else { return "–" }
    return first.uppercased() + raw.dropFirst()
}

nonisolated func nodeCheckStateColor(_ state: Node64.CheckStateKind?) -> Color {
    switch state {
    case .up: .ipv64Green
    case .down: .ipv64Red
    case .degraded, .flapping: .ipv64Orange
    default: .ipv64Gray
    }
}

/// Event kind title: "_" → " ", first letter uppercased; blank → fallback.
nonisolated func healthcheckEventTitle(kind: String?, fallback: String) -> String {
    guard let kind = kind?.nonBlank else { return fallback }
    let text = kind.replacingOccurrences(of: "_", with: " ")
    return text.prefix(1).uppercased() + text.dropFirst()
}

/// Event/state helper: kind → state (`down`, `up`, `degraded`, `flapping_*`, …).
nonisolated func healthcheckEventState(kind: String?, to: String?) -> Hc2StateUi {
    switch kind?.lowercased() {
    case "down", "reminder": .down
    case "up", "degraded_end", "flapping_end": .up
    case "degraded": .degraded
    case "flapping_start": .flapping
    default: Hc2StateUi.from(to)
    }
}

// MARK: - Stats chart

/// Index of the time nearest to `fraction` (0…1) on the axis; relative to `tMin` for precision.
nonisolated func nearestIndex(_ times: [Double], tMin: Double, tMax: Double, fraction: Double) -> Int {
    let target = (tMax - tMin) * min(max(fraction, 0), 1)
    var best = 0
    var bestDistance = Double.greatestFiniteMagnitude
    for (i, t) in times.enumerated() {
        let d = abs((t - tMin) - target)
        if d < bestDistance { bestDistance = d; best = i }
    }
    return best
}

/// Day/week/month/year buckets show a date (UTC), others date + time (local).
nonisolated func formatBucketTime(_ date: Date, dayBucket: Bool) -> String {
    let gregorian = Calendar(identifier: .gregorian)
    if dayBucket {
        return date.formatted(Date.VerbatimFormatStyle(
            format: "\(day: .twoDigits).\(month: .twoDigits).\(year: .padded(4))",
            timeZone: TimeZone(identifier: "UTC") ?? .gmt, calendar: gregorian))
    }
    return date.formatted(Date.VerbatimFormatStyle(
        format: "\(day: .twoDigits).\(month: .twoDigits).\(year: .padded(4)) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
        timeZone: .current, calendar: gregorian))
}

// MARK: - Durations (spec B4/B5)

nonisolated let durationUnits: [(name: String, seconds: Int)] = [
    ("seconds", 1), ("minutes", 60), ("hours", 3600), ("days", 86_400),
]

/// Seconds → (value, unit index) using the largest unit that divides exactly.
nonisolated func secondsToDuration(_ seconds: Int?) -> (String, Int) {
    guard let seconds, seconds > 0 else { return ("", 1) }
    for idx in durationUnits.indices.reversed() where seconds % durationUnits[idx].seconds == 0 {
        return (String(seconds / durationUnits[idx].seconds), idx)
    }
    return (String(seconds), 0)
}

/// Blank → `nil` (server default), invalid / out of range → -1.
nonisolated func durationToSeconds(_ value: String, unitIdx: Int) -> Int? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    guard let n = Int64(trimmed) else { return -1 }
    let unit = Int64(durationUnits[min(max(unitIdx, 0), durationUnits.count - 1)].seconds)
    let (total, overflow) = n.multipliedReportingOverflow(by: unit)
    return !overflow && total >= 0 && total <= Int64(Int32.max) ? Int(total) : -1
}

/// Integers without ".0".
nonisolated func hcFormatNumber(_ value: Double?) -> String {
    guard let value else { return "" }
    return value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int64(value)) : String(value)
}

nonisolated func hcParseTags(_ text: String) -> [String] {
    var seen = Set<String>()
    return text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && seen.insert($0).inserted }
}

// MARK: - Execution (spec B4)

nonisolated struct ExecutionFields: Equatable, Sendable {
    var execution: HC2Execution
    var nodeId: String?
    var locations: [String]?
}

/// Online → locations only, node → node only, both → both.
nonisolated func executionFields(_ execution: HC2Execution, nodeId: String?, locations: [String]) -> ExecutionFields {
    ExecutionFields(execution: execution,
                    nodeId: execution == .online ? nil : nodeId,
                    locations: execution == .local ? nil : locations)
}

/// Does the change need `checks.move()`? (a missing old execution counts as online)
nonisolated func executionMoveNeeded(
    oldExec: HC2Execution?, oldNodeId: String?, oldLocations: [String],
    exec: HC2Execution, nodeId: String?, locations: [String]
) -> Bool {
    (oldExec ?? .online) != exec
        || (exec != .online && nodeId != oldNodeId)
        || (exec != .local && Set(locations) != Set(oldLocations))
}

nonisolated enum MoveClassification: Equatable, Sendable {
    case applied
    case failed(String)
    /// pending / running
    case running
}

/// Android `Hc2MoveRunner.classify`.
nonisolated func classifyTestrun(_ run: HC2Testrun) -> MoveClassification {
    switch run.status?.rawValue.lowercased() {
    case "ok": return .applied
    case "failed": return .failed(testrunFailureMessage(run))
    case "expired": return .failed(String(localized: "The test run expired before it finished."))
    default: return .running
    }
}

nonisolated func testrunFailureMessage(_ run: HC2Testrun) -> String {
    let messages = (run.results ?? []).filter { $0.ok != true }.compactMap { result -> String? in
        guard let message = result.message?.nonBlank else { return nil }
        return result.source.map { "\($0): \(message)" } ?? message
    }
    if !messages.isEmpty { return messages.joined(separator: "\n") }
    if let error = run.error?.nonBlank { return error }
    return String(localized: "The test run failed. The change was not applied.")
}

/// Command output as text (JSON string value or JSON-encoded), trimmed, first 400 chars; `nil` if empty.
nonisolated func commandOutputText(_ output: JSONValue?) -> String? {
    guard let output, output != .null else { return nil }
    let text: String
    if let string = output.stringValue {
        text = string
    } else if let data = try? JSONEncoder().encode(output) {
        text = String(decoding: data, as: UTF8.self)
    } else {
        return nil
    }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : String(trimmed.prefix(400))
}
