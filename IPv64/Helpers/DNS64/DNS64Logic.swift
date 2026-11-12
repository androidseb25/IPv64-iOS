import Foundation
import IPv64

// Pure DNS64 helpers (Android parity). Callable from any isolation.

nonisolated enum Dns64Time { case hm, dayMonth, dayMonthHm }

/// `HH:mm`, `dd.MM.`, `dd.MM. HH:mm` in the device time zone.
nonisolated func dns64Format(_ date: Date, _ kind: Dns64Time) -> String {
    let calendar = Calendar(identifier: .gregorian)
    switch kind {
    case .hm:
        return date.formatted(Date.VerbatimFormatStyle(
            format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            timeZone: .current, calendar: calendar))
    case .dayMonth:
        return date.formatted(Date.VerbatimFormatStyle(
            format: "\(day: .twoDigits).\(month: .twoDigits).", timeZone: .current, calendar: calendar))
    case .dayMonthHm:
        return date.formatted(Date.VerbatimFormatStyle(
            format: "\(day: .twoDigits).\(month: .twoDigits). \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            timeZone: .current, calendar: calendar))
    }
}

/// One decimal with a dot, "0" for an empty whole.
nonisolated func dns64Percent(_ part: Int, of whole: Int) -> String {
    whole > 0 ? String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), Double(part) * 100 / Double(whole)) : "0"
}

nonisolated func dns64Ms(_ value: Double?) -> String {
    value.map { String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? "–"
}

/// Delay until the next countdown tick: 1 s under 2 minutes, else 30 s.
nonisolated func dns64CountdownInterval(remaining: TimeInterval) -> Duration {
    remaining < 120 ? .seconds(1) : .seconds(30)
}

nonisolated func dns64BlockingTitle(paused: Bool, end: Date?, now: Date) -> String {
    guard paused else { return String(localized: "Blocking active") }
    guard let end else { return String(localized: "Paused until resumed") }
    let remaining = max(end.timeIntervalSince(now), 0)
    let until = dns64Format(end, .hm)
    if remaining < 120 { return String(localized: "Paused · \(Int(remaining)) s left (until \(until))") }
    return String(localized: "Paused · \(Int(remaining / 60) + 1) min left (until \(until))")
}

// MARK: - Chart

nonisolated struct Dns64Bar: Identifiable, Equatable, Sendable {
    let index: Int
    let start: Date?
    let allowed: Int
    let blocked: Int
    var id: Int { index }
}

/// Timeline buckets to bars; Allowed = max(total - blocked, 0).
nonisolated func dns64Bars(_ buckets: [Node64.DNS64TimelineBucket]) -> [Dns64Bar] {
    buckets.enumerated().map { i, b in
        let blocked = b.blocked ?? 0
        return Dns64Bar(index: i, start: b.date, allowed: max((b.total ?? 0) - blocked, 0), blocked: blocked)
    }
}

// MARK: - Query log

nonisolated enum Dns64LogFilter: String, CaseIterable, Identifiable, Sendable {
    case all, blocked, allowed
    var id: String { rawValue }
    /// Raw status sent to the node (`nil` = all).
    var rawStatus: String? { self == .all ? nil : rawValue }
}

/// Chip of a log row from the raw (open) status: blocked red, error orange, allowed/cached green, else gray.
nonisolated func dns64StatusTag(_ raw: String?) -> ProxyLogic.Tag {
    switch raw {
    case "blocked": .init(text: String(localized: "Blocked"), tone: .red)
    case "error": .init(text: String(localized: "Error"), tone: .orange)
    case "allowed", "cached": .init(text: raw!.capitalized, tone: .green)
    case let other: .init(text: other?.nonBlank?.capitalized ?? "–", tone: .gray)
    }
}

nonisolated func dns64AllowMessage(reason: String?) -> String {
    let by = reason?.nonBlank.map { " by \($0)" } ?? ""
    return String(localized: "Blocked\(by). Allow this domain and its subdomains for all clients?")
}

// MARK: - Records

nonisolated let dns64RecordTypes = ["A", "AAAA", "CNAME", "TXT", "MX", "SRV", "PTR", "CAA"]

nonisolated func dns64DigitsOnly(_ text: String) -> String { text.filter { $0.isASCII && $0.isNumber } }

nonisolated func dns64RecordValid(name: String, value: String, ttl: String) -> Bool {
    name.nonBlank != nil && value.nonBlank != nil && (ttl.isEmpty || Int(ttl) != nil)
}

/// Edit sends the trimmed text (empty clears), create `nil` when empty.
nonisolated func dns64Comment(_ text: String, isEdit: Bool) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return isEdit || !trimmed.isEmpty ? trimmed : nil
}

/// Keeps a flag `nil` while it was never set and is still off; otherwise the toggle value.
nonisolated func dns64Flag(original: Bool?, toggle: Bool) -> Bool? {
    original == nil && !toggle ? nil : toggle
}
