import Foundation

// Pure DNS64 helpers (spec 03 §6–§9). Callable from any isolation, unit-testable.

// MARK: - Domain

/// Android `normalizeDns64Domain`: lowercased host without scheme/path/query/trailing dot, `nil` if not a domain.
nonisolated func normalizeDns64Domain(_ input: String) -> String? {
    var d = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    for prefix in ["https://", "http://"] where d.hasPrefix(prefix) { d.removeFirst(prefix.count) }
    d = String(d.prefix { $0 != "/" }.prefix { $0 != "?" })
    while d.hasSuffix(".") { d.removeLast() }
    if d.isEmpty || !d.contains(".") { return nil }
    if d.hasPrefix(".") || d.contains("..") { return nil }
    guard d.allSatisfy({ $0.isLetter || $0.isNumber || "-_.*".contains($0) }) else { return nil }
    return d
}

// MARK: - Formatting

nonisolated enum Dns64Time { case hm, dayMonth, dayMonthHm }

/// German patterns `HH:mm`, `dd.MM.`, `dd.MM. HH:mm` in the device time zone.
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

/// `whole > 0 ? "%.1f" (dot) : "0"`.
nonisolated func dns64Percent(_ part: Int, of whole: Int) -> String {
    whole > 0 ? String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), Double(part) * 100 / Double(whole)) : "0"
}

/// `"%.0f"` (dot) of an optional millisecond value, "–" when missing.
nonisolated func dns64Ms(_ value: Double?) -> String {
    value.map { String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? "–"
}

/// Integer division `total / hours` (caption "≈ n per hour").
nonisolated func dns64PerHour(total: Int, hours: Int) -> Int { hours > 0 ? total / hours : 0 }

// MARK: - Blocking countdown

/// Delay until the next countdown tick: 1 s under 2 minutes, else 30 s.
nonisolated func dns64CountdownInterval(remaining: TimeInterval) -> Duration {
    remaining < 120 ? .seconds(1) : .seconds(30)
}

/// Title of the blocking row (spec 03 §6.3).
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
    var total: Int { allowed + blocked }
}

/// Timeline buckets → bars; Allowed = max(total − blocked, 0).
nonisolated func dns64Bars(_ buckets: [(t: Int?, total: Int?, blocked: Int?)]) -> [Dns64Bar] {
    buckets.enumerated().map { i, b in
        let blocked = b.blocked ?? 0
        return Dns64Bar(index: i, start: b.t.map { Date(timeIntervalSince1970: Double($0) / 1000) },
                        allowed: max((b.total ?? 0) - blocked, 0), blocked: blocked)
    }
}

/// Largest stacked bar, at least 1.
nonisolated func dns64MaxBar(_ bars: [Dns64Bar]) -> Int { max(bars.map(\.total).max() ?? 0, 1) }

/// Axis label indices `[0, (n-1)/3, 2(n-1)/3, n-1]`, distinct.
nonisolated func dns64AxisIndices(count n: Int) -> [Int] {
    guard n > 0 else { return [] }
    var seen = Set<Int>()
    return [0, (n - 1) / 3, 2 * (n - 1) / 3, n - 1].filter { seen.insert($0).inserted }
}

// MARK: - Query log

nonisolated enum Dns64LogFilter: String, CaseIterable, Identifiable, Sendable {
    case all, blocked, allowed
    var id: String { rawValue }
    /// Raw `DNS64QueryStatus` value sent to the node (`nil` = all).
    var rawStatus: String? { self == .all ? nil : rawValue }
}

nonisolated enum Dns64StatusTone: Sendable { case red, orange, green, gray }

/// Chip of a log row from the raw status (open enum): blocked red, error orange, allowed/cached green, else gray.
nonisolated func dns64StatusChip(_ raw: String?) -> (label: String, tone: Dns64StatusTone) {
    switch raw {
    case "blocked": (String(localized: "Blocked"), .red)
    case "error": (String(localized: "Error"), .orange)
    case "allowed", "cached": (raw!.capitalized, .green)
    case let other: (other?.nonBlankCapitalized ?? "–", .gray)
    }
}

private nonisolated extension String {
    var nonBlankCapitalized: String? { isEmpty ? nil : capitalized }
}

/// Subtitle of a log row (spec 03 §8).
nonisolated func dns64LogSubtitle(time: String, clientName: String?, client: String?, qtype: String?,
                                  upstream: String?, ms: Double?, status: String?, domain: String?,
                                  reason: String?) -> String {
    let who = clientName?.nonBlankValue ?? client ?? "–"
    var text = "\(time) · \(who)" + (qtype.map { " · \($0)" } ?? "")
    if upstream != nil || ms != nil {
        text += "\n" + (upstream ?? "") + (ms.map { " \(dns64Ms($0)) ms" } ?? "")
    }
    if status == "blocked", domain != nil, let reason = reason?.nonBlankValue { text += "\n" + reason }
    return text
}

/// Message of the allow dialog.
nonisolated func dns64AllowMessage(reason: String?) -> String {
    let by = reason?.nonBlankValue.map { " by \($0)" } ?? ""
    return String(localized: "Blocked\(by). Allow this domain and its subdomains for all clients?")
}

private nonisolated extension String {
    var nonBlankValue: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}

// MARK: - Records

nonisolated let dns64RecordTypes = ["A", "AAAA", "CNAME", "TXT", "MX", "SRV", "PTR", "CAA"]

nonisolated func dns64DigitsOnly(_ text: String) -> String { text.filter { $0.isASCII && $0.isNumber } }

nonisolated func dns64RecordValid(name: String, value: String, ttl: String) -> Bool {
    let blank = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    return !blank(name) && !blank(value) && (ttl.isEmpty || Int(ttl) != nil)
}

/// Comment payload: edit sends the trimmed text (empty clears), create `nil` when empty.
nonisolated func dns64Comment(_ text: String, isEdit: Bool) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return isEdit || !trimmed.isEmpty ? trimmed : nil
}

/// Keeps a flag `nil` while it was never set and is still off; otherwise the toggle value.
nonisolated func dns64Flag(original: Bool?, toggle: Bool) -> Bool? {
    original == nil && !toggle ? nil : toggle
}
