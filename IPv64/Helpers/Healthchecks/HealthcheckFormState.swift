import Foundation
import IPv64

// Form state of the account healthcheck form (spec 02 B4). Pure and nonisolated.

nonisolated struct HealthcheckFormState: Equatable, Sendable {
    var type: HC2CheckType = .http
    var name = ""
    var target = ""
    var ps = ParamsState.initial(.http)
    /// Parameters as loaded (dirty check, "was something there" for clearing).
    var iniPs = ParamsState.initial(.http)
    var intervalValue = ""
    var intervalUnit = 1
    var retryValue = ""
    var retryUnit = 1
    var retries = ""
    var timeout = ""
    var connectTimeout = ""
    var stabilize = ""
    var invert = false
    var ipMode: HC2IPMode?
    var locations: [String] = []
    var policy: HC2Policy?
    var execSel: HC2Execution = .online
    var nodeId: String?
    var notifyDown = true
    var notifyUp = true
    var notifyDegraded = false
    var critical = false
    var repeatMinutes: Int?
    var useDefaultChannels = true
    var channels: Set<Int> = []
    var tags = ""
    var group = ""
    var description = ""
    var createPaused = false

    // MARK: Derived

    var execution: HC2Execution { type == .push ? .online : execSel }
    var online: Bool { execution == .online }
    var nodeOnly: Bool { execution == .local }
    var usesLocations: Bool { execution != .local && type != .push }
    var policyApplies: Bool { (usesLocations && locations.count > 1) || execution == .both }

    // MARK: Detail → state

    /// `knownChannelIds`: unknown (deleted) channel ids are dropped; none left → default channels.
    mutating func apply(_ d: HC2CheckDetail, knownChannelIds: Set<Int>) {
        let t = d.type ?? .http
        type = t
        name = d.name ?? ""
        target = d.target ?? ""
        ps = ParamsState.from(t, d.params)
        iniPs = ps
        (intervalValue, intervalUnit) = secondsToDuration(d.intervalSeconds)
        (retryValue, retryUnit) = secondsToDuration(d.retryIntervalSeconds)
        retries = d.retries.map(String.init) ?? ""
        timeout = hcFormatNumber(d.timeoutSeconds)
        connectTimeout = hcFormatNumber(d.connectTimeoutSeconds)
        stabilize = d.stabilize.map(String.init) ?? ""
        invert = d.invert ?? false
        ipMode = d.ipMode
        locations = (d.locations ?? []).map(\.rawValue)
        policy = d.policy
        execSel = d.execution ?? .online
        nodeId = d.nodeID?.nonBlank
        notifyDown = d.notifyDown ?? true
        notifyUp = d.notifyUp ?? true
        notifyDegraded = d.notifyDegraded ?? false
        critical = d.critical ?? false
        repeatMinutes = d.repeatMinutes
        let known = Set(d.channels ?? []).intersection(knownChannelIds)
        channels = known
        useDefaultChannels = known.isEmpty
        tags = (d.tags ?? []).joined(separator: ", ")
        group = d.group ?? ""
        description = d.description ?? ""
    }

    // MARK: Validation

    /// Which collapsed section holds the problem.
    enum FormSection: Sendable { case main, advanced, notifications }

    /// First failing rule (spec B4 validation 1–12).
    func validate(maxLocations: Int?) -> (message: String, section: FormSection)? {
        if name.nonBlank == nil { return (String(localized: "Please enter a name."), .main) }
        if type != .push && target.nonBlank == nil { return (String(localized: "Please enter a target."), .main) }
        if let issue = ps.validateIssue(type, target: target) { return (issue.message, issue.inAdvanced ? .advanced : .main) }
        let interval = durationToSeconds(intervalValue, unitIdx: intervalUnit)
        if let interval, interval < 20 { return (String(localized: "Interval must be at least 20 seconds."), .advanced) }
        let retry = durationToSeconds(retryValue, unitIdx: retryUnit)
        if let retry, retry < 5 { return (String(localized: "Retry interval must be at least 5 seconds."), .advanced) }
        if retries.nonBlank != nil, !(Int(retries.hcTrimmed).map { (0...10).contains($0) } ?? false) {
            return (String(localized: "Retries must be between 0 and 10."), .advanced)
        }
        if stabilize.nonBlank != nil, !(Int(stabilize.hcTrimmed).map { (1...20).contains($0) } ?? false) {
            return (String(localized: "Stabilize must be between 1 and 20."), .advanced)
        }
        if timeout.nonBlank != nil, !(Double(timeout.hcTrimmed).map { $0 > 0 } ?? false) {
            return (String(localized: "Timeout must be greater than 0."), .advanced)
        }
        if connectTimeout.nonBlank != nil, !(Double(connectTimeout.hcTrimmed).map { $0 > 0 } ?? false) {
            return (String(localized: "Connect timeout must be greater than 0."), .advanced)
        }
        if usesLocations && type != .push {
            if locations.isEmpty { return (String(localized: "Select at least one location."), .main) }
            if let maxLocations, locations.count > maxLocations {
                return (String(localized: "Your plan allows up to \(maxLocations) locations per check."), .main)
            }
        }
        if !online && nodeId == nil { return (String(localized: "Select a node."), .main) }
        if !useDefaultChannels && channels.isEmpty {
            return (String(localized: "Select at least one channel or use the default channels."), .notifications)
        }
        return nil
    }

    // MARK: Requests

    private var trimmedName: String { name.hcTrimmed }
    private var trimmedTarget: String? { type == .push ? nil : target.hcTrimmed }

    /// Create request (`saveCreate`).
    func createInput() -> HC2CheckInput {
        let fields = executionFields(execution, nodeId: nodeId, locations: locations)
        var input = HC2CheckInput(
            name: trimmedName, type: type, target: trimmedTarget,
            params: ps.toParams(type, ini: iniPs),
            intervalSeconds: durationToSeconds(intervalValue, unitIdx: intervalUnit).flatMap { $0 >= 0 ? $0 : nil },
            retryIntervalSeconds: durationToSeconds(retryValue, unitIdx: retryUnit).flatMap { $0 >= 0 ? $0 : nil },
            retries: Int(retries.hcTrimmed), connectTimeoutSeconds: Double(connectTimeout.hcTrimmed),
            timeoutSeconds: Double(timeout.hcTrimmed), invert: invert, ipMode: ipMode,
            tags: hcParseTags(tags), group: group.hcTrimmed.nonBlank, description: description.hcTrimmed.nonBlank,
            paused: createPaused, critical: critical, execution: execution,
            nodeID: fields.nodeId, nodes: nil,
            locations: type == .push ? nil : fields.locations.map { $0.map(HC2Location.init(rawValue:)) },
            policy: policyApplies ? policy : nil,
            notifyDegraded: notifyDegraded, notifyDown: notifyDown, notifyUp: notifyUp,
            channels: useDefaultChannels ? [] : channels.sorted(), repeatMinutes: repeatMinutes)
        input.stabilize = Int(stabilize.hcTrimmed)
        return input
    }

    /// Does the edit change execution, node or locations (needs `checks.move`)?
    func moveNeeded(old: HC2CheckDetail) -> Bool {
        type != .push && executionMoveNeeded(
            oldExec: old.execution, oldNodeId: old.nodeID, oldLocations: (old.locations ?? []).map(\.rawValue),
            exec: execution, nodeId: nodeId, locations: locations)
    }

    /// Minimal diff against the loaded check (`buildUpdate`). `name`/`type` are always set (GAP: the SPM input
    /// requires them); `hasChanges` tells whether anything else differs. Never sends execution/locations/node.
    func updateInput(old: HC2CheckDetail, moveNeeded: Bool) -> (input: HC2CheckInput, hasChanges: Bool) {
        var changed = false
        func diff<T: Equatable>(_ new: T?, _ old: T?) -> T? {
            guard let new, new != old else { return nil }
            changed = true
            return new
        }
        func text(_ new: String, _ old: String?) -> String? {
            let value = new.hcTrimmed
            if value == (old ?? "").hcTrimmed { return nil }
            changed = true
            return value
        }
        var input = HC2CheckInput(name: trimmedName, type: old.type ?? type)
        if trimmedName != (old.name ?? "") { changed = true }
        if type != .push { input.target = text(target, old.target) }
        if ps != iniPs {
            input.params = ps.toParams(type, ini: iniPs)
            changed = true
        }
        input.intervalSeconds = diff(durationToSeconds(intervalValue, unitIdx: intervalUnit), old.intervalSeconds)
        input.retryIntervalSeconds = diff(durationToSeconds(retryValue, unitIdx: retryUnit), old.retryIntervalSeconds)
        input.retries = diff(Int(retries.hcTrimmed), old.retries)
        input.connectTimeoutSeconds = diff(Double(connectTimeout.hcTrimmed), old.connectTimeoutSeconds)
        input.timeoutSeconds = diff(Double(timeout.hcTrimmed), old.timeoutSeconds)
        input.stabilize = diff(Int(stabilize.hcTrimmed), old.stabilize)
        input.invert = diff(invert, old.invert ?? false)
        input.ipMode = diff(ipMode, old.ipMode)
        let newTags = hcParseTags(tags)
        if Set(newTags) != Set(old.tags ?? []) || newTags.count != (old.tags ?? []).count {
            input.tags = newTags
            changed = true
        }
        input.group = text(group, old.group)
        input.description = text(description, old.description)
        let newChannels: [Int] = useDefaultChannels ? [] : channels.sorted()
        if Set(newChannels) != Set(old.channels ?? []) {
            input.channels = newChannels
            changed = true
        }
        input.notifyDegraded = diff(notifyDegraded, old.notifyDegraded ?? false)
        input.notifyDown = diff(notifyDown, old.notifyDown ?? true)
        input.notifyUp = diff(notifyUp, old.notifyUp ?? true)
        input.critical = diff(critical, old.critical ?? false)
        input.repeatMinutes = diff(repeatMinutes, old.repeatMinutes)
        if policyApplies && !moveNeeded { input.policy = diff(policy, old.policy) }
        return (input, changed)
    }
}

nonisolated extension String {
    var hcTrimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Helpers (ported from Android 2.1.0 HealthcheckLogic)

nonisolated let healthcheckRepeatOptions: [Int?] = [nil, 0, 5, 10, 15, 30, 60, 120, 360, 720, 1440]

/// Order of the type picker when creating a check.
nonisolated let healthcheckCreateTypes: [HC2CheckType] = [.http, .keyword, .json, .dns, .icmp, .tcp, .port, .cert, .push, .whois]

nonisolated extension HC2CheckType {
    /// Placeholder of the target field.
    var targetHint: String {
        switch self {
        case .http, .keyword, .json: "https://example.com/health"
        case .dns, .whois: "example.com"
        case .icmp: "example.com or IP address"
        case .tcp, .port: "host:port"
        case .cert: "example.com or host:port"
        default: ""
        }
    }
}

nonisolated let durationUnits: [(name: String, seconds: Int)] = [("seconds", 1), ("minutes", 60), ("hours", 3600), ("days", 86_400)]

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
    case running
}

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

/// Result of an execution change (`checks.move` + test run).
enum MoveOutcome: Equatable {
    case applied
    case failed(String)
    case timedOut
}

/// Starts the move and polls the test run every 2 s for at most 60 s.
func runHealthcheckMove(api: IPv64, token: String, fields: ExecutionFields) async throws -> MoveOutcome {
    let run = try await ipv64Retrying {
        try await api.hc2.checks.move(token, execution: fields.execution, nodeID: fields.nodeId, nodes: nil,
                                      locations: fields.locations?.map(HC2Location.init(rawValue:)))
    }
    var current = run
    for _ in 0..<30 {
        switch classifyTestrun(current) {
        case .applied: return .applied
        case .failed(let message): return .failed(message)
        case .running: break
        }
        try await Task.sleep(for: .seconds(2))
        current = try await api.hc2.checks.testrun(run.id)
    }
    return .timedOut
}
