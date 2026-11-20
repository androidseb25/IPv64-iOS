import SwiftUI
import IPv64

// Monitor64 hosts of connected nodes in the Healthchecks tab (Android 2.2.0). Pure and nonisolated.

/// Pushed from the list.
struct Monitor64HostRoute: Hashable {
    let nodeId: String
    let uid: String
}

/// Where "+" creates the new healthcheck.
enum HealthcheckTarget: Hashable {
    case account
    case nodeCheck(String)
    case monitor64Host(String)
}

/// Monitor64 hosts of one node in the list; no entry = module off or node not reachable.
nonisolated struct Monitor64ListData: Sendable {
    var hosts: [Node64.Monitor64OverviewHost] = []
    /// Set when Monitor64 answered with an error other than 404.
    var error: String?
}

/// 404 means the module is off (or the host is gone).
nonisolated func isNodeNotFound(_ error: any Error) -> Bool {
    guard let error = error as? Node64Error else { return false }
    switch error {
    case .api(let e): return e.status == 404
    case .httpStatus(let code, _): return code == 404
    default: return false
    }
}

/// Displayed state of a host or problem: text and colour; `paused` wins.
nonisolated struct Monitor64Display: Sendable {
    let label: String
    let color: Color
    /// Status-filter bucket; `nil` = only in "All". Not derived from `label`, which is localized.
    var bucket: HcStatusFilter?

    static func host(view: String?, paused: Bool?) -> Monitor64Display {
        if paused == true { return Monitor64Display(label: String(localized: "Paused"), color: .gray, bucket: .paused) }
        switch view {
        case "ok": return Monitor64Display(label: String(localized: "OK"), color: .green, bucket: .up)
        case "warn": return Monitor64Display(label: String(localized: "Warning"), color: .orange, bucket: .degraded)
        case "crit": return Monitor64Display(label: String(localized: "Critical"), color: .red, bucket: .down)
        case "unreachable": return Monitor64Display(label: String(localized: "Unreachable"), color: .red, bucket: .down)
        case "maintenance": return Monitor64Display(label: String(localized: "Maintenance"), color: .gray, bucket: .paused)
        default: return Monitor64Display(label: String(localized: "Unknown"), color: .gray)
        }
    }

    static func service(_ state: String?) -> Monitor64Display {
        switch state {
        case "ok": Monitor64Display(label: String(localized: "OK"), color: .green, bucket: .up)
        case "warn": Monitor64Display(label: String(localized: "Warning"), color: .orange, bucket: .degraded)
        case "crit": Monitor64Display(label: String(localized: "Critical"), color: .red, bucket: .down)
        default: Monitor64Display(label: String(localized: "Unknown"), color: .gray)
        }
    }

    /// ok = Up, warn = Degraded, crit/unreachable = Down, paused/maintenance = Paused.
    func matches(_ filter: HcStatusFilter) -> Bool {
        filter == .all || bucket == filter
    }
}

nonisolated extension Node64.Monitor64OverviewHost {
    var display: Monitor64Display { .host(view: view?.rawValue, paused: paused) }
}

nonisolated extension String {
    /// The node sends untranslated keys ("i18n:monitor64.svc.fs?name=%2F"): last key part plus parameter values ("fs /").
    var m64Text: String {
        guard let regex = try? NSRegularExpression(pattern: #"i18n:([\w.\-]+)(?:\?([^\s]*))?"#) else { return self }
        let result = NSMutableString(string: self)
        for match in regex.matches(in: self, range: NSRange(startIndex..., in: self)).reversed() {
            func group(_ i: Int) -> String {
                Range(match.range(at: i), in: self).map { String(self[$0]) } ?? ""
            }
            let word = (group(1).split(separator: ".").last.map(String.init) ?? group(1)).replacingOccurrences(of: "_", with: " ")
            let values = group(2).split(separator: "&", omittingEmptySubsequences: false).compactMap { part -> String? in
                guard let eq = part.firstIndex(of: "=") else { return nil }
                let value = String(part[part.index(after: eq)...])
                return value.isEmpty ? nil : (value.removingPercentEncoding ?? value)
            }
            result.replaceCharacters(in: match.range, with: values.isEmpty ? word : "\(word) \(values.joined(separator: " / "))")
        }
        return result as String
    }
}

nonisolated let monitor64HostKinds: [Node64.Monitor64HostKind] = [
    .unspecified, .linuxAgent, .windows, .freebsd, .ssh, .pve, .pbs, .docker, .truenas, .unraid, .server, .ups, .prom, .snmp, .nas,
]

nonisolated let monitor64AccessTypes: [Node64.Monitor64AccessType] = [
    .agent, .ssh, .pve, .pbs, .docker, .prom, .nut, .truenas, .unraid, .redfish, .snmp,
]

nonisolated extension Node64.Monitor64HostKind {
    var label: String { self == .unspecified ? String(localized: "None") : rawValue }
}

/// Access form fields. The server checks strictly "only fields of the access type", so only non-empty fields are sent.
nonisolated struct Monitor64AccessDraft: Hashable, Sendable {
    /// Existing access; `nil` = new.
    var uid: String?
    /// `nil` = no access (creating a host).
    var type: Node64.Monitor64AccessType?
    var port = ""
    var user = ""
    var url = ""
    var tokenId = ""
    /// Write-only.
    var secret = ""
    var enabled = true
    /// Config as loaded: the PUT replaces it, so fields not shown here must be kept.
    var base: Node64.Monitor64AccessConfig?
    /// Confirmed fingerprint: hostkey for SSH, else `config.pin`.
    var fingerprint: String?

    init(uid: String? = nil, type: Node64.Monitor64AccessType? = nil) {
        self.uid = uid
        self.type = type
    }

    init(_ a: Node64.Monitor64AccessState) {
        uid = a.uid
        type = a.type ?? .agent
        port = a.config?.port.flatMap { $0 > 0 ? String($0) : nil } ?? ""
        user = a.config?.user ?? ""
        url = a.config?.url ?? ""
        tokenId = a.config?.tokenID ?? ""
        enabled = a.enabled != false
        base = a.config ?? Node64.Monitor64AccessConfig()
    }

    /// Changing the target invalidates a test and a confirmed fingerprint.
    var targetKey: String { [type?.rawValue ?? "", port, user, url, tokenId, secret].joined(separator: "\u{1}") }

    func input() -> Node64.Monitor64AccessInput? {
        guard let type else { return nil }
        let ssh = type == .ssh
        var config = base ?? Node64.Monitor64AccessConfig()
        config.port = Int(port.hcTrimmed)
        config.user = user.nonBlank?.hcTrimmed
        config.url = url.nonBlank?.hcTrimmed
        config.tokenID = tokenId.nonBlank?.hcTrimmed
        if !ssh, let fingerprint { config.pin = fingerprint }
        return Node64.Monitor64AccessInput(
            type: type,
            config: base != nil || config != Node64.Monitor64AccessConfig() ? config : nil,
            secret: secret.isEmpty ? nil : secret,
            hostkey: ssh ? fingerprint : nil,
            enabled: uid == nil ? nil : enabled)
    }
}
