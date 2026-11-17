import SwiftUI
import IPv64

// Texts and small helpers of the healthcheck detail (ported from Android 2.1.0 Formatters / Hc2CheckUi).

nonisolated enum HcFormat {
    /// Go zero dates (year 0001) and the epoch count as "no date".
    static func real(_ date: Date?) -> Date? {
        guard let date, date.timeIntervalSince1970 > 0 else { return nil }
        return date
    }

    static func time(_ date: Date?) -> String? {
        real(date).map { DynDNSLogic.germanTime($0) }
    }

    static func timeWithRelative(_ date: Date?) -> String? {
        guard let date = real(date) else { return nil }
        return "\(DynDNSLogic.germanTime(date)) (\(date.formatted(.relative(presentation: .named))))"
    }

    static func latency(_ value: Double?) -> String {
        guard let value else { return "–" }
        return value.formatted(.number.precision(.fractionLength(0...(value < 10 ? 1 : 0)))) + " ms"
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "–" }
        return value.formatted(.number.precision(.fractionLength(0...2))) + " %"
    }

    static func duration(seconds: Int) -> String {
        if seconds <= 0 { return "0 s" }
        var rest = seconds
        var parts: [String] = []
        for (size, name) in [(86_400, "d"), (3600, "h"), (60, "min"), (1, "s")] where parts.count < 2 {
            let n = rest / size
            if n > 0 {
                parts.append("\(n) \(name)")
                rest -= n * size
            }
        }
        return parts.joined(separator: " ")
    }

    static func seconds(_ value: Double) -> String { duration(seconds: Int(value.rounded())) }

    static func repeatMinutes(_ minutes: Int) -> String {
        minutes <= 0 ? String(localized: "Off") : duration(seconds: minutes * 60)
    }

    static func yesNo(_ value: Bool?) -> String? {
        value.map { $0 ? String(localized: "Yes") : String(localized: "No") }
    }

    /// Event kind title: "_" becomes a space, first letter uppercased; blank gives the fallback.
    static func eventTitle(kind: String?, fallback: String) -> String {
        guard let kind = kind?.nonBlank else { return fallback }
        let text = kind.replacingOccurrences(of: "_", with: " ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    static func eventState(kind: String?, to: String?) -> Hc2StateUi {
        switch kind?.lowercased() {
        case "down", "reminder": .down
        case "up", "degraded_end", "flapping_end": .up
        case "degraded": .degraded
        case "flapping_start": .flapping
        default: Hc2StateUi.from(state: to.flatMap { HC2CheckState(rawValue: $0.lowercased()) }, paused: false)
        }
    }

    /// Channel name, else type label, else type, else `Channel #id`.
    static func channelName(_ channel: HC2Channel) -> String {
        channel.name?.trimmingCharacters(in: .whitespaces).nonBlank ?? channel.typeLabel?.nonBlank
            ?? channel.type?.rawValue.nonBlank ?? String(localized: "Channel #\(channel.id)")
    }

    /// Command output as text (JSON string or JSON-encoded), trimmed, first 400 characters.
    static func commandOutput(_ output: JSONValue?) -> String? {
        guard let output, output != .null else { return nil }
        let text = output.stringValue ?? (try? JSONEncoder().encode(output)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(400))
    }

    /// Only http(s) targets of http, keyword and json checks can be opened.
    static func browserURL(type: HC2CheckType?, target: String?) -> URL? {
        guard let type, [.http, .keyword, .json].contains(type),
              let target, target.lowercased().hasPrefix("http") else { return nil }
        return URL(string: target)
    }
}

nonisolated extension Hc2StateUi {
    static func from(state: HC2CheckState?, paused: Bool?) -> Hc2StateUi {
        if paused == true { return .paused }
        switch state {
        case .up: return .up
        case .down: return .down
        case .degraded: return .degraded
        case .flapping: return .flapping
        case .paused: return .paused
        default: return .pending
        }
    }
}
