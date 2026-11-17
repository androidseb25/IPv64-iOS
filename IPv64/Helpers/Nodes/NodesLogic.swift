import Foundation
import IPv64

/// Pure logic of the node screens (Android NodeSupport.kt, NodeLocalView.kt).
nonisolated enum NodesLogic {
    /// Stored / cloud name, else "Node …" + last 4 characters of the id.
    static func nodeName(_ name: String?, nodeId: String) -> String {
        name?.nonBlank ?? "Node …" + String(nodeId.suffix(4))
    }

    /// Remote management label (`off`/`read`/`full`/nil).
    static func remoteLabel(_ remote: String?) -> String {
        switch remote {
        case "off": String(localized: "Off")
        case "read": String(localized: "Read only")
        case "full": String(localized: "Full")
        default: String(localized: "Unknown")
        }
    }

    /// Cloud row meta line: location, "v"+version, "seen …" joined " · ", `nil` when all are missing.
    static func cloudMeta(location: String?, version: String?, lastSeen: Date?) -> String? {
        let parts = [
            location?.nonBlank,
            version?.nonBlank.map { "v" + $0 },
            lastSeen.map { String(localized: "seen \($0.formatted(.relative(presentation: .named)))") },
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Remote: Full" plus " · N conflict(s)".
    static func remoteLine(_ remote: String?, conflicts: Int?) -> String {
        var line = String(localized: "Remote: \(remoteLabel(remote))")
        let count = conflicts ?? 0
        if count > 0 {
            line += " · " + (count == 1 ? String(localized: "1 conflict") : String(localized: "\(count) conflicts"))
        }
        return line
    }

    /// Direct node row subtitle: host of the stored URL, else the URL.
    static func directSubtitle(url: String?) -> String {
        guard let url else { return "" }
        return LocalNodeURL.host(of: url) ?? url
    }

    /// Android: every character of the key must be printable ASCII (`!`…`~`).
    static func isValidApiKey(_ key: String) -> Bool {
        key.unicodeScalars.allSatisfy { (0x21...0x7E).contains($0.value) }
    }

    /// Live warning under the form: none, orange (http on the local network) or red (http over the internet).
    enum InsecureWarning: Equatable, Sendable { case none, local, internet }

    static func insecureWarning(for address: String) -> InsecureWarning {
        guard let url = LocalNodeURL.normalizeLocalNodeUrl(address), url.hasPrefix("http://") else { return .none }
        return LocalNodeURL.isPublicHttp(url) ? .internet : .local
    }

    static func remoteDescription(_ remote: String) -> String {
        switch remote {
        case "off": String(localized: "Remote management is off.")
        case "read": String(localized: "Read access, the node does not accept commands.")
        default: String(localized: "Commands from ipv64.net (run check, repair, pause, resume) are accepted.")
        }
    }

    // MARK: Link code

    /// Letters/digits, uppercased, max 8 (raw value of the "Code" field).
    static func rawLinkCode(_ input: String) -> String {
        String(input.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.uppercased().prefix(8))
    }

    /// "ABCD-EFGH" display mask of a raw code.
    static func maskedLinkCode(_ raw: String) -> String {
        raw.count > 4 ? raw.prefix(4) + "-" + raw.dropFirst(4) : raw
    }

    // MARK: Live state

    enum LiveState: Equatable, Sendable {
        case connecting, paused, offline, live

        static func from(lastOk: Date?, active: Bool, failing: Bool) -> LiveState {
            if lastOk == nil { return .connecting }
            if !active { return .paused }
            return failing ? .offline : .live
        }
    }

    /// "Updated just now" / "Updated 12 s ago".
    static func updatedText(since lastOk: Date, now: Date = .now) -> String {
        let seconds = Int(now.timeIntervalSince(lastOk))
        return seconds < 2 ? String(localized: "Updated just now")
            : String(localized: "Updated \(HcFormat.duration(seconds: seconds)) ago")
    }

    /// HTTP 401/403 of the node (shown as the "rejected" line in the header).
    static func isAuthRejection(_ error: any Error) -> Bool {
        guard let error = error as? Node64Error else { return false }
        return error.statusCode == 401 || error.statusCode == 403
    }

    // MARK: Logs

    /// One parsed logfmt line; missing fields are `nil`.
    struct LogEntry: Equatable, Sendable {
        var time: String?
        var level: String?
        var module: String?
        var msg: String?
    }

    /// logfmt (`time=… level=INFO msg="a b"`): quoted values with `\"`, `\\`, `\n`, `\t`, `\r`; the first duplicate
    /// key wins; `nil` = not logfmt (a word without "=", or neither `level` nor `msg`).
    static func parseLogLine(_ line: String) -> LogEntry? {
        let chars = Array(line)
        var fields: [String: String] = [:]
        var i = 0
        let n = chars.count
        while i < n {
            while i < n && chars[i].isWhitespace { i += 1 }
            if i >= n { break }
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
                    } else {
                        value.append(chars[i])
                    }
                    i += 1
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
        return LogEntry(time: fields["time"], level: fields["level"]?.uppercased(), module: fields["module"], msg: fields["msg"])
    }

    /// ISO timestamp → `HH:mm:ss` in the device time zone, `nil` when unreadable.
    static func logClock(_ iso: String?) -> String? {
        guard let iso = iso?.trimmingCharacters(in: .whitespaces), !iso.isEmpty else { return nil }
        let date = (try? Date(iso, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
            ?? (try? Date(iso, strategy: Date.ISO8601FormatStyle()))
        return date.map { $0.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)) }
    }

    /// One log element → text: string → itself; object with `msg` → logfmt of the present keys; else JSON.
    static func logText(_ element: JSONValue) -> String {
        if case .string(let s) = element { return s }
        if case .object(let object) = element, object["msg"] != nil {
            return ["time", "level", "module", "msg"].compactMap { key in
                object[key].map { "\(key)=\"\(escapeLogfmt(jsonString($0)))\"" }
            }.joined(separator: " ")
        }
        return jsonString(element)
    }

    static func jsonString(_ value: JSONValue) -> String {
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

    private static func escapeLogfmt(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    // MARK: Commands

    static func commandLabel(_ name: String?) -> String {
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

    /// Command history args text: check name / "Conflict #id" / "keep side".
    static func commandArgsText(_ args: JSONValue?, checkName: (String) -> String) -> String? {
        guard case .object(let object)? = args else { return nil }
        var parts: [String] = []
        if let token = object["token"].map(jsonString) { parts.append(checkName(token)) }
        if let id = object["id"].map(jsonString) { parts.append("Conflict #\(id)") }
        if let keep = object["keep"].map(jsonString) { parts.append("keep \(keep)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Unlink result: "N checks continued as online checks, N checks deleted. The node keeps running standalone."
    static func unlinkSummary(kept: Int, deleted: Int) -> String {
        var parts: [String] = []
        if kept > 0 {
            parts.append(kept == 1 ? String(localized: "1 check continued as online check")
                         : String(localized: "\(kept) checks continued as online checks"))
        }
        if deleted > 0 {
            parts.append(deleted == 1 ? String(localized: "1 check deleted") : String(localized: "\(deleted) checks deleted"))
        }
        let counts = parts.joined(separator: ", ")
        return counts.isEmpty ? String(localized: "The node keeps running standalone.")
            : String(localized: "\(counts). The node keeps running standalone.")
    }

    // MARK: Module screens

    /// ISO-3166 alpha-2 → flag emoji, `nil` if not two letters.
    static func countryFlag(_ code: String?) -> String? {
        guard let code = code?.uppercased(), code.count == 2, code.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        return String(String.UnicodeScalarView(code.unicodeScalars.compactMap { Unicode.Scalar(127_397 + $0.value) }))
    }

    /// DNS64 blocked share: below 10 one decimal, else whole percent; "–" without queries.
    static func blockedPercent(total: Int, blocked: Int) -> String {
        guard total > 0 else { return "–" }
        let p = Double(blocked) * 100 / Double(total)
        return p < 10 ? p.formatted(.number.precision(.fractionLength(1))) + " %" : "\(Int(p)) %"
    }
}
