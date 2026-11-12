import Foundation
import IPv64

// Logic of the node healthchecks (Node64 `hc.checks`; Android 2.1.0). Pure and nonisolated.

/// Node64 type order of the form (docker and proxmox no longer exist since 2.x).
nonisolated let nodeCheckTypes: [Node64.CheckType] = [.http, .keyword, .json, .dns, .icmp, .tcp, .port, .cert, .whois, .push]

nonisolated extension Node64.CheckType {
    /// The same type as account check (labels, symbols and hints are shared).
    var hc2: HC2CheckType { HC2CheckType(rawValue: rawValue) }
    var label: String { hc2.label }
}

/// Node64 timestamps are ISO 8601 strings; Go zero dates are removed later by `HcFormat.real`.
nonisolated func nodeDate(_ iso: String?) -> Date? {
    guard let iso = iso?.trimmingCharacters(in: .whitespaces), !iso.isEmpty else { return nil }
    return (try? Date(iso, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        ?? (try? Date(iso, strategy: Date.ISO8601FormatStyle()))
}

nonisolated extension Node64.Check {
    var uiState: Hc2StateUi {
        Hc2StateUi.from(state: state?.state.map { HC2CheckState(rawValue: $0.rawValue) }, paused: paused)
    }

    /// `owner != online && owner != other` (nil, "self" and unknown count as owned by the node).
    var isNodeOwned: Bool { owner != .online && owner != .other }
}

/// State of the healthchecks module of a node.
nonisolated enum NodeChecksModule: Sendable { case on, off, missing }

nonisolated func nodeChecksModule(_ modules: [Node64.ModuleStatus]?) -> NodeChecksModule {
    guard let modules, !modules.isEmpty else { return .on }
    guard let module = modules.first(where: { ["checks", "healthchecks"].contains($0.name.lowercased()) }) else { return .missing }
    return module.enabled == false ? .off : .on
}

/// Stored result of one connected node in the list.
nonisolated struct NodeChecksData: Sendable {
    var module: NodeChecksModule
    var checks: [Node64.Check] = []
    /// Set when the node could not be reached.
    var error: String?

    /// Checks owned by the node itself (others belong to the account).
    var owned: [Node64.Check] { checks.filter(\.isNodeOwned) }
}

/// Pushed from the list.
struct NodeCheckRoute: Hashable {
    let nodeId: String
    let token: String
}

/// Form state of the node check sheet. Pure and nonisolated.
nonisolated struct NodeCheckFormState: Equatable, Sendable {
    var type: Node64.CheckType = .http
    var name = ""
    var target = ""
    var keyword = ""
    var port = ""
    var recordType: HC2DNSRecordType = .a
    var intervalValue = ""
    var intervalUnit = 1
    var retryValue = ""
    var retryUnit = 1
    var retries = ""
    var timeout = ""
    var connectTimeout = ""
    var stabilize = ""
    var invert = false
    var ipMode: Node64.CheckIPMode?
    var notifyDown = true
    var notifyUp = true
    var notifyDegraded = false
    var critical = false
    var repeatMinutes: Int?
    var tags = ""
    var group = ""
    var description = ""
    var createPaused = false
    /// Loaded check (edit); `nil` when creating.
    var base: Node64.Check?

    var editing: Bool { base != nil }

    mutating func apply(_ c: Node64.Check) {
        base = c
        name = c.name ?? ""
        type = c.type ?? .http
        target = c.target ?? ""
        keyword = c.params?["keyword"]?.stringValue ?? ""
        port = c.params?["port"].flatMap { $0.intValue.map(String.init) ?? $0.stringValue } ?? ""
        recordType = c.params?["record_type"]?.stringValue.map(HC2DNSRecordType.init(rawValue:)) ?? .a
        (intervalValue, intervalUnit) = secondsToDuration(c.intervalSeconds)
        (retryValue, retryUnit) = secondsToDuration(c.retryIntervalSeconds)
        retries = c.retries.map(String.init) ?? ""
        timeout = hcFormatNumber(c.timeoutSeconds)
        connectTimeout = hcFormatNumber(c.connectTimeoutSeconds)
        stabilize = c.stabilize.map(String.init) ?? ""
        invert = c.invert ?? false
        ipMode = c.ipMode
        notifyDown = c.notifyDown ?? true
        notifyUp = c.notifyUp ?? true
        notifyDegraded = c.notifyDegraded ?? false
        critical = c.critical ?? false
        repeatMinutes = c.repeatMinutes
        tags = (c.tags ?? []).joined(separator: ", ")
        group = c.group ?? ""
        description = c.description ?? ""
    }

    /// First failing rule, `nil` when the form can be saved.
    func validate() -> String? {
        if name.nonBlank == nil { return String(localized: "Please enter a name.") }
        if type != .push && target.nonBlank == nil { return String(localized: "Please enter a target.") }
        if type == .keyword && keyword.nonBlank == nil { return String(localized: "Please enter a keyword.") }
        if (type == .tcp || type == .port || type == .cert), port.nonBlank != nil, Int(port.hcTrimmed) == nil {
            return String(localized: "Port must be a number.")
        }
        if durationToSeconds(intervalValue, unitIdx: intervalUnit) == -1 || durationToSeconds(retryValue, unitIdx: retryUnit) == -1 {
            return String(localized: "Interval is not valid.")
        }
        if retries.nonBlank != nil, !(Int(retries.hcTrimmed).map { (0...10).contains($0) } ?? false) {
            return String(localized: "Retries must be between 0 and 10.")
        }
        if stabilize.nonBlank != nil, !(Int(stabilize.hcTrimmed).map { (1...20).contains($0) } ?? false) {
            return String(localized: "Stabilize must be between 1 and 20.")
        }
        if timeout.nonBlank != nil, !(Double(timeout.hcTrimmed).map { $0 > 0 } ?? false) {
            return String(localized: "Timeout must be greater than 0.")
        }
        if connectTimeout.nonBlank != nil, !(Double(connectTimeout.hcTrimmed).map { $0 > 0 } ?? false) {
            return String(localized: "Connect timeout must be greater than 0.")
        }
        return nil
    }

    /// Request. The update (PUT) is built from the loaded check: name, type and target are always sent,
    /// the description is sent as text (nil would clear it), everything not in the form keeps its value.
    func input() -> Node64.CheckInput {
        var params = base?.params ?? [:]
        switch type {
        case .keyword: params["keyword"] = keyword.nonBlank.map { .string($0.hcTrimmed) }
        case .tcp, .port, .cert: params["port"] = Int(port.hcTrimmed).map { .number(Double($0)) }
        case .dns: params["record_type"] = .string(recordType.rawValue)
        default: break
        }
        let seconds: (String, Int) -> Int? = { durationToSeconds($0, unitIdx: $1).flatMap { $0 >= 0 ? $0 : nil } }
        return Node64.CheckInput(
            name: name.hcTrimmed, type: type,
            target: type == .push ? (editing ? "" : nil) : target.hcTrimmed,
            params: params.isEmpty ? nil : params,
            intervalSeconds: seconds(intervalValue, intervalUnit) ?? base?.intervalSeconds,
            retryIntervalSeconds: seconds(retryValue, retryUnit) ?? base?.retryIntervalSeconds,
            retries: Int(retries.hcTrimmed) ?? base?.retries,
            connectTimeoutSeconds: Double(connectTimeout.hcTrimmed) ?? base?.connectTimeoutSeconds,
            timeoutSeconds: Double(timeout.hcTrimmed) ?? base?.timeoutSeconds,
            invert: invert,
            stabilize: Int(stabilize.hcTrimmed) ?? base?.stabilize,
            ipMode: ipMode ?? base?.ipMode,
            tags: hcParseTags(tags),
            description: editing ? description.hcTrimmed : description.hcTrimmed.nonBlank,
            paused: editing ? base?.paused : createPaused,
            parent: base?.parent,
            critical: critical,
            execution: base?.execution,
            policy: base?.policy,
            locations: base?.locations.flatMap { $0.isEmpty ? nil : $0 },
            notifyDegraded: notifyDegraded,
            notifyDown: notifyDown,
            notifyUp: notifyUp,
            channels: base?.channels.flatMap { $0.isEmpty ? nil : $0 },
            repeatMinutes: repeatMinutes ?? base?.repeatMinutes,
            group: editing ? group.hcTrimmed : group.hcTrimmed.nonBlank,
            nodes: base?.nodes.flatMap { $0.isEmpty ? nil : $0 })
    }
}
