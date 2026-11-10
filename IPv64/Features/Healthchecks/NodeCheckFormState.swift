import Foundation
import IPv64

/// Form state of the node check edit screen (spec 02 B7). Pure and nonisolated.
nonisolated struct NodeCheckFormState: Equatable, Sendable {
    var name = ""
    var type: Node64.CheckType?
    var target = ""
    var keyword = ""
    var port = ""
    var recordType: HC2DNSRecordType = .a
    var interval = ""
    var retryInterval = ""
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
    var startPaused = false
    /// Loaded check (edit); `nil` when creating.
    var base: Node64.Check?

    var editing: Bool { base != nil }

    mutating func apply(_ c: Node64.Check) {
        base = c
        name = c.name ?? ""
        type = c.type
        target = c.target ?? ""
        keyword = c.params?["keyword"]?.stringValue ?? ""
        port = c.params?["port"].flatMap { $0.intValue.map(String.init) ?? $0.stringValue } ?? ""
        recordType = c.params?["record_type"]?.stringValue.map(HC2DNSRecordType.init(rawValue:)) ?? .a
        interval = c.intervalSeconds.map(String.init) ?? ""
        retryInterval = c.retryIntervalSeconds.map(String.init) ?? ""
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

    /// Error message (spec B7 validation) or `nil`.
    func validate() -> String? {
        let numbers: [(String, String, Bool)] = [
            (String(localized: "Interval"), interval, false), (String(localized: "Retries"), retries, false),
            (String(localized: "Retry interval"), retryInterval, false), (String(localized: "Timeout"), timeout, true),
            (String(localized: "Connect timeout"), connectTimeout, true), (String(localized: "Stabilize"), stabilize, false),
            (String(localized: "Port"), port, false),
        ]
        for (label, value, decimal) in numbers where value.nonBlank != nil {
            let ok = decimal ? Double(value.hcTrimmed) != nil : Int(value.hcTrimmed) != nil
            if !ok { return String(localized: "\(label) must be a number.") }
        }
        if name.nonBlank == nil { return String(localized: "Enter a name.") }
        guard let type else { return String(localized: "Choose a type.") }
        if type != .push && target.nonBlank == nil { return String(localized: "Enter a target.") }
        if type == .keyword && keyword.nonBlank == nil { return String(localized: "Enter a keyword.") }
        return nil
    }

    /// `flag(v, default)`: sent when editing or when it differs from the default.
    private func flag(_ value: Bool, _ fallback: Bool) -> Bool? { (editing || value != fallback) ? value : nil }

    /// Save request: merges into the loaded params; PUT semantics on update.
    func input() -> Node64.CheckInput? {
        guard let type else { return nil }
        var params = base?.params ?? [:]
        switch type {
        case .keyword:
            if let keyword = keyword.nonBlank { params["keyword"] = .string(keyword.hcTrimmed) } else { params["keyword"] = nil }
        case .tcp, .port, .cert:
            if let port = Int(port.hcTrimmed) { params["port"] = .number(Double(port)) } else { params["port"] = nil }
        case .dns:
            params["record_type"] = .string(recordType.rawValue)
        default:
            break
        }
        let newTags = hcParseTags(tags)
        return Node64.CheckInput(
            name: name.hcTrimmed, type: type, target: target.hcTrimmed.nonBlank,
            params: params.isEmpty ? nil : params,
            intervalSeconds: Int(interval.hcTrimmed) ?? base?.intervalSeconds,
            retryIntervalSeconds: Int(retryInterval.hcTrimmed) ?? base?.retryIntervalSeconds,
            retries: Int(retries.hcTrimmed) ?? base?.retries,
            connectTimeoutSeconds: Double(connectTimeout.hcTrimmed) ?? base?.connectTimeoutSeconds,
            timeoutSeconds: Double(timeout.hcTrimmed) ?? base?.timeoutSeconds,
            invert: flag(invert, false),
            stabilize: Int(stabilize.hcTrimmed) ?? base?.stabilize,
            ipMode: ipMode ?? base?.ipMode,
            tags: (editing || !newTags.isEmpty) ? newTags : nil,
            description: description.hcTrimmed,
            paused: editing ? nil : startPaused,
            parent: base?.parent,
            critical: flag(critical, false),
            execution: base?.execution,
            policy: base?.policy,
            locations: base?.locations.flatMap { $0.isEmpty ? nil : $0 },
            notifyDegraded: flag(notifyDegraded, false),
            notifyDown: flag(notifyDown, true),
            notifyUp: flag(notifyUp, true),
            channels: base?.channels.flatMap { $0.isEmpty ? nil : $0 },
            repeatMinutes: repeatMinutes ?? base?.repeatMinutes,
            group: (editing || group.nonBlank != nil) ? group.hcTrimmed : nil,
            nodes: base?.nodes.flatMap { $0.isEmpty ? nil : $0 })
    }
}
