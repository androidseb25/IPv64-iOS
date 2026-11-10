import Foundation
import IPv64

// Pure node logic (Android NodeLogParser.kt, NodeSupport.kt, NodeModuleView.kt, NodeCommandViews.kt). Callable from any isolation.

/// One parsed logfmt line; missing fields are `nil`.
nonisolated struct NodeLogEntry: Equatable, Sendable {
    var time: String?
    var level: String?
    var module: String?
    var msg: String?
}

/// logfmt (`time=… level=INFO msg="a b" module=x`): values optionally quoted (`\"`, `\\`, `\n`, `\t`, `\r`),
/// the first duplicate key wins, `nil` = not logfmt (a word without "=", or neither `level` nor `msg`).
nonisolated func parseNodeLogLine(_ line: String) -> NodeLogEntry? {
    let chars = Array(line)
    var fields: [String: String] = [:]
    var i = 0
    let n = chars.count
    while i < n {
        while i < n && chars[i].isWhitespace { i += 1 }
        let keyStart = i
        while i < n && chars[i] != "=" && !chars[i].isWhitespace { i += 1 }
        guard i < n, chars[i] == "=", i != keyStart else { return nil }
        let key = String(chars[keyStart..<i])
        i += 1
        var value = ""
        if i < n && chars[i] == "\"" {
            i += 1
            while i < n && chars[i] != "\"" {
                if chars[i] == "\\" && i + 1 < n {
                    i += 1
                    switch chars[i] {
                    case "n": value.append("\n")
                    case "t": value.append("\t")
                    case "r": value.append("\r")
                    default: value.append(chars[i])
                    }
                    i += 1
                } else {
                    value.append(chars[i])
                    i += 1
                }
            }
            i += 1
        } else {
            while i < n && !chars[i].isWhitespace {
                value.append(chars[i])
                i += 1
            }
        }
        if fields[key] == nil { fields[key] = value }
    }
    guard fields["level"] != nil || fields["msg"] != nil else { return nil }
    return NodeLogEntry(time: fields["time"], level: fields["level"]?.uppercased(), module: fields["module"], msg: fields["msg"])
}

/// ISO timestamp → `HH:mm:ss` in the device time zone, `nil` when unreadable.
nonisolated func nodeLogClock(_ iso: String?) -> String? {
    Formatters.parseISO(iso).map(Formatters.clock)
}

/// Android `moduleLabel`: case-insensitive; `nil` = no screen for this module.
nonisolated func moduleLabel(_ name: String) -> String? {
    switch name.lowercased() {
    case "honeypot": String(localized: "Honeypot")
    case "dns64": String(localized: "DNS64")
    case "cdn64": String(localized: "CDN64 / Proxy")
    case "dyndns": String(localized: "DynDNS")
    case "checks", "healthchecks": String(localized: "Healthchecks")
    default: nil
    }
}

nonisolated func hasModuleScreen(_ name: String) -> Bool { moduleLabel(name) != nil }

/// Remote management label (`off`/`read`/`full`/nil).
nonisolated func remoteLabel(_ remote: String?) -> String {
    switch remote {
    case "off": String(localized: "Off")
    case "read": String(localized: "Read only")
    case "full": String(localized: "Full")
    default: String(localized: "Unknown")
    }
}

nonisolated func remoteDescription(_ remote: String) -> String {
    switch remote {
    case "off": String(localized: "Remote management is off.")
    case "read": String(localized: "Read access, the node does not accept commands.")
    default: String(localized: "Commands from ipv64.net (run check, repair, pause, resume) are accepted.")
    }
}

/// Cloud node row subtitle: `[location, "v"+version, "seen "+lastSeen]` joined " · ", then "Remote: …" on a second line.
nonisolated func cloudNodeSubtitle(location: String?, version: String?, lastSeen: Date?, remote: String?, conflicts: Int?) -> String {
    let meta = [
        location?.nonBlank,
        version?.nonBlank.map { "v" + $0 },
        Formatters.ago(lastSeen).map { String(localized: "seen \($0)") },
    ].compactMap { $0 }.joined(separator: " · ")
    let count = conflicts ?? 0
    var remoteLine = String(localized: "Remote: \(remoteLabel(remote))")
    if count > 0 {
        remoteLine += " · " + (count == 1 ? String(localized: "\(count) conflict") : String(localized: "\(count) conflicts"))
    }
    return meta.isEmpty ? remoteLine : meta + "\n" + remoteLine
}

/// Direct node row subtitle: host of the stored URL, else the URL.
nonisolated func directNodeSubtitle(url: String?) -> String {
    guard let url else { return "" }
    return LocalNodeURL.host(of: url) ?? url
}

/// Link code: letters/digits, uppercased, max 8 (raw value of the "Code" field).
nonisolated func rawLinkCode(_ input: String) -> String {
    String(input.filter { $0.isLetter || $0.isNumber }.uppercased().prefix(8))
}

/// "ABCD-EFGH" display mask of a raw code.
nonisolated func maskedLinkCode(_ raw: String) -> String {
    raw.count > 4 ? raw.prefix(4) + "-" + raw.dropFirst(4) : raw
}

/// Live chip state of a direct node.
nonisolated enum NodeLiveState: Equatable, Sendable {
    case connecting, paused, offline, live

    static func from(lastOk: Date?, resumed: Bool, failing: Bool) -> NodeLiveState {
        if lastOk == nil { return .connecting }
        if !resumed { return .paused }
        return failing ? .offline : .live
    }
}

/// "Updated just now" / "Updated 12 s ago".
nonisolated func updatedText(since lastOk: Date, now: Date = .now) -> String {
    let seconds = Int(now.timeIntervalSince(lastOk))
    return seconds < 2 ? String(localized: "Updated just now")
        : String(localized: "Updated \(Formatters.duration(seconds: seconds)) ago")
}

// MARK: - Commands

nonisolated func commandLabel(_ name: String?) -> String {
    switch name {
    case "run_check": String(localized: "Run check")
    case "repair": String(localized: "Repair")
    case "pause": String(localized: "Pause check")
    case "resume": String(localized: "Resume check")
    case "resolve_conflict": String(localized: "Resolve conflict")
    case let other?: other
    case nil: String(localized: "Command")
    }
}

/// Output / JSON text: primitive → its text, else compact JSON; trimmed, max 400 chars, `nil` when empty.
nonisolated func jsonOutputText(_ value: JSONValue?) -> String? {
    guard let value, value != .null else { return nil }
    let text = value.stringValue ?? jsonString(value)
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : String(trimmed.prefix(400))
}

nonisolated func jsonString(_ value: JSONValue) -> String {
    switch value {
    case .string(let s): return s
    case .null: return "null"
    case .bool(let b): return b ? "true" : "false"
    case .number(let d): return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(d)
    default:
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}

/// One log element → text: string → itself; object with `msg` → logfmt of the present keys; else JSON.
nonisolated func nodeLogText(_ element: JSONValue) -> String {
    if case .string(let s) = element { return s }
    if case .object(let object) = element, object["msg"] != nil {
        return ["time", "level", "module", "msg"].compactMap { key in
            object[key].map { "\(key)=\"\(escapeLogfmt(jsonString($0)))\"" }
        }.joined(separator: " ")
    }
    return jsonString(element)
}

private nonisolated func escapeLogfmt(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
}

/// Android `countryFlag`: ISO-3166 alpha-2 → flag emoji, `nil` if not two letters.
nonisolated func countryFlagEmoji(_ code: String?) -> String? {
    guard let code = code?.uppercased(), code.count == 2, code.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
    return String(String.UnicodeScalarView(code.unicodeScalars.compactMap { Unicode.Scalar(127_397 + $0.value) }))
}

/// Unlink result text: `"N check(s) continued as online check(s)"`, `"N check(s) deleted"`.
nonisolated func unlinkSummary(kept: Int, deleted: Int) -> String {
    var parts: [String] = []
    if kept > 0 { parts.append(kept == 1 ? String(localized: "1 check continued as online check")
                               : String(localized: "\(kept) checks continued as online checks")) }
    if deleted > 0 { parts.append(deleted == 1 ? String(localized: "1 check deleted") : String(localized: "\(deleted) checks deleted")) }
    let counts = parts.joined(separator: ", ")
    return counts.isEmpty ? String(localized: "The node keeps running standalone.")
        : String(localized: "\(counts). The node keeps running standalone.")
}

// MARK: - Direct access form

/// Android: every character of the key must be printable ASCII (`!`…`~`).
nonisolated func isValidNodeApiKey(_ key: String) -> Bool {
    key.unicodeScalars.allSatisfy { (0x21...0x7E).contains($0.value) }
}

/// Live warning under the form: `.none`, orange (local http) or red (http over a public IP/name).
nonisolated enum InsecureWarning: Equatable, Sendable { case none, local, internet }

nonisolated func insecureWarning(for address: String) -> InsecureWarning {
    guard let url = LocalNodeURL.normalizeLocalNodeUrl(address), url.hasPrefix("http://") else { return .none }
    return LocalNodeURL.isPublicHttp(url) ? .internet : .local
}

// MARK: - Detail helpers

/// HTTP 401/403 of the node (shown as "rejected" line in the detail header).
nonisolated func isNodeAuthRejection(_ error: any Error) -> Bool {
    guard let error = error as? Node64Error else { return false }
    switch error {
    case .api(let e): return e.status == 401 || e.status == 403
    case .httpStatus(let code, _): return code == 401 || code == 403
    default: return false
    }
}

/// `Hc2CheckType.label`.
nonisolated func checkTypeLabel(_ raw: String?) -> String {
    switch raw {
    case "http": "HTTP(S)"
    case "keyword": "Keyword"
    case "json": "JSON"
    case "dns": "DNS"
    case "icmp": "Ping (ICMP)"
    case "tcp": "TCP"
    case "port": "Port"
    case "cert": "Certificate"
    case "push": "Push"
    case "docker": "Docker"
    case "whois": "WHOIS"
    default: "Unknown"
    }
}

/// Command history args text: check name / "Conflict #id" / "keep side".
nonisolated func commandArgsText(_ args: JSONValue?, checkName: (String) -> String) -> String? {
    guard case .object(let object)? = args else { return nil }
    var parts: [String] = []
    if let token = object["token"].map(jsonString) { parts.append(checkName(token)) }
    if let id = object["id"].map(jsonString) { parts.append("Conflict #\(id)") }
    if let keep = object["keep"].map(jsonString) { parts.append("keep \(keep)") }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
}
