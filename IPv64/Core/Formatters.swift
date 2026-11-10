import Foundation
import IPv64

/// Exact Android formats (helper/Extensions.kt, spec 01 §7.3). Pure, callable from any isolation.
nonisolated enum Formatters {
    private static var gregorian: Calendar { Calendar(identifier: .gregorian) }

    /// `dd.MM.yyyy` in the device time zone.
    static func german(_ date: Date) -> String {
        date.formatted(Date.VerbatimFormatStyle(
            format: "\(day: .twoDigits).\(month: .twoDigits).\(year: .padded(4))",
            timeZone: .current, calendar: gregorian))
    }

    /// `dd.MM.yyyy HH:mm:ss` in the device time zone.
    static func germanTime(_ date: Date) -> String {
        date.formatted(Date.VerbatimFormatStyle(
            format: "\(day: .twoDigits).\(month: .twoDigits).\(year: .padded(4)) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
            timeZone: .current, calendar: gregorian))
    }

    /// `HH:mm:ss` in the device time zone (log lines, node clock).
    static func clock(_ date: Date) -> String {
        date.formatted(Date.VerbatimFormatStyle(
            format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
            timeZone: .current, calendar: gregorian))
    }

    /// Android `Instant.realOrNull()`: `nil` for epoch <= 0 (Go zero time 0001-01-01).
    static func realOrNil(_ date: Date?) -> Date? {
        guard let date, date.timeIntervalSince1970 > 0 else { return nil }
        return date
    }

    /// `germanTime` of a real date, `fallback` otherwise (e.g. "none").
    static func germanTime(_ date: Date?, fallback: String) -> String {
        realOrNil(date).map(germanTime) ?? fallback
    }

    /// ISO-8601 string (with or without fractional seconds) → Date; Node64 timestamps are strings.
    static func parseISO(_ string: String?) -> Date? {
        guard let string = string?.trimmingCharacters(in: .whitespaces), !string.isEmpty else { return nil }
        if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return realOrNil(date)
        }
        return realOrNil(try? Date(string, strategy: Date.ISO8601FormatStyle()))
    }

    /// Android `Instant.formatRelative()`.
    static func relative(_ date: Date, now: Date = .now) -> String {
        let diff = Int(now.timeIntervalSince(date))
        if diff < 0 { return germanTime(date) }
        if diff < 60 { return String(localized: "just now") }
        if diff < 3600 { return String(localized: "\(diff / 60) min ago") }
        if diff < 86_400 { return String(localized: "\(diff / 3600) h ago") }
        if diff < 30 * 86_400 { return String(localized: "\(diff / 86_400) d ago") }
        return german(date)
    }

    /// Android `Instant?.ago()`: `nil` for missing/zero dates.
    static func ago(_ date: Date?) -> String? { realOrNil(date).map { relative($0) } }

    /// Android `Long.formatBytes()`: "512 B", "1.0 KB", "1.5 MB" (device decimal separator).
    static func bytes(_ n: Int64) -> String {
        if n < 1024 { return "\(n) B" }
        let exp = min(Int(log(Double(n)) / log(1024)), 6)
        let units = Array("KMGTPE")
        let value = Double(n) / pow(1024, Double(exp))
        return value.formatted(.number.precision(.fractionLength(1)).grouping(.never)) + " \(units[exp - 1])B"
    }

    /// Android `Double.formatUsage()`: locale grouping, at most 2 fraction digits.
    static func usage(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    /// Android `UsageCounter?.usageText()`: "3 / 10", "3 / ∞", "–".
    static func usageText(_ quota: Me.Quota?) -> String {
        guard let quota else { return "–" }
        let limit = quota.limit.map { usage(Double($0)) } ?? "∞"
        return "\(usage(quota.used ?? 0)) / \(limit)"
    }

    /// Android `VpnTrafficUsage?.usageText()`.
    static func usageText(_ quota: Me.TrafficQuota?) -> String {
        guard let quota, let limit = quota.limit else { return "–" }
        let text = "\(usage(quota.used ?? 0)) / \(usage(Double(limit)))"
        return quota.limited == true ? text + String(localized: " (limit reached)") : text
    }

    /// Android `Double?.formatPercent()`: "99.95 %".
    static func percent(_ value: Double?) -> String {
        guard let value else { return "–" }
        return value.formatted(.number.precision(.fractionLength(0...2))) + " %"
    }

    /// Android `Double?.formatLatency()`: "4.5 ms", "12 ms".
    static func latency(_ value: Double?) -> String {
        guard let value else { return "–" }
        return value.formatted(.number.precision(.fractionLength(0...(value < 10 ? 1 : 0)))) + " ms"
    }

    /// Android `Long.formatCount()`: locale grouping.
    static func count(_ value: Int) -> String { value.formatted() }

    /// Android `formatSeconds` / `Long.formatDuration()`: at most two greedy parts, "1 h 30 min".
    static func duration(seconds: Int) -> String {
        if seconds <= 0 { return "0 s" }
        let units: [(Int, String)] = [(86_400, "d"), (3600, "h"), (60, "min"), (1, "s")]
        var rest = seconds
        var parts: [String] = []
        for (size, name) in units where parts.count < 2 {
            let n = rest / size
            if n > 0 {
                parts.append("\(n) \(name)")
                rest -= n * size
            }
        }
        return parts.joined(separator: " ")
    }

    /// Android `repeatMinutesLabel(m)`.
    static func repeatMinutes(_ minutes: Int?) -> String {
        guard let minutes else { return "–" }
        return minutes <= 0 ? String(localized: "Off") : duration(seconds: minutes * 60)
    }

    /// Android node `displayName`: name if non-blank, else "Node …" + last 4 chars of the id.
    static func nodeName(_ name: String?, nodeId: String) -> String {
        name?.nonBlank ?? "Node …" + String(nodeId.suffix(4))
    }
}
