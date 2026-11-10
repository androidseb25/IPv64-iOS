import Foundation
import IPv64

/// Form state of the notification settings; number fields as text ("" = not set). Android `SettingsForm`.
nonisolated struct NotificationSettingsForm: Equatable, Sendable {
    var quietEnabled = false
    var from = "22:00"
    var to = "07:00"
    var days: Set<Int> = Set(1...7)
    var rate = ""
    var threshold = ""
    var window = ""
}

/// Pure logic of `Hc2SettingsView.kt` (spec 04 §7b).
nonisolated enum NotificationSettingsLogic {
    static let quietKeys = ["quiet_from", "quiet_to", "quiet_days"]

    /// Flat map: `notify.<key>` or bare `<key>`.
    static func value(_ map: [String: String], _ key: String) -> String? { map["notify." + key] ?? map[key] }

    /// Parsed form plus the keys the server actually sent.
    static func parse(_ map: [String: String]) -> (form: NotificationSettingsForm, present: Set<String>) {
        let defaults = NotificationSettingsForm()
        var present = Set<String>()
        func read(_ key: String) -> String? {
            let v = value(map, key)
            if v != nil { present.insert(key) }
            return v
        }
        let enabled = read("quiet_enabled").map { ["1", "true", "yes", "on"].contains($0.trimmingCharacters(in: .whitespaces).lowercased()) }
        let from = normalizeTime(read("quiet_from"))
        let to = normalizeTime(read("quiet_to"))
        let days = read("quiet_days").map(parseDays).flatMap { $0.isEmpty ? nil : $0 }
        func number(_ key: String) -> String { read(key).flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }.map(String.init) ?? "" }
        let form = NotificationSettingsForm(quietEnabled: enabled ?? defaults.quietEnabled, from: from ?? defaults.from,
                                            to: to ?? defaults.to, days: days ?? defaults.days, rate: number("rate_per_hour"),
                                            threshold: number("batch_threshold"), window: number("batch_window_seconds"))
        return (form, present)
    }

    /// Android `normalizeTimeOfDay`: "22:00", "22:00:00", "2200" → "HH:MM"; invalid → nil.
    static func normalizeTime(_ text: String?) -> String? {
        let s = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !s.isEmpty else { return nil }
        let parts = s.split(separator: ":", omittingEmptySubsequences: false)
        let h: Int, m: Int
        if parts.count >= 2 {
            guard let hh = Int(parts[0]), let mm = Int(parts[1]) else { return nil }
            (h, m) = (hh, mm)
        } else if s.count == 4, s.allSatisfy(\.isNumber), let hh = Int(s.prefix(2)), let mm = Int(s.suffix(2)) {
            (h, m) = (hh, mm)
        } else {
            return nil
        }
        guard (0...23).contains(h), (0...59).contains(m) else { return nil }
        return String(format: "%02d:%02d", h, m)
    }

    /// "1,2,3" or ranges "1-5"; values 1…7.
    static func parseDays(_ text: String) -> Set<Int> {
        var result = Set<Int>()
        for part in text.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !part.isEmpty {
            if part.contains("-") {
                let bounds = part.split(separator: "-", maxSplits: 1).map { Int($0.trimmingCharacters(in: .whitespaces)) }
                if bounds.count == 2, let a = bounds[0], let b = bounds[1], a <= b {
                    result.formUnion((a...b).filter { (1...7).contains($0) })
                }
            } else if let day = Int(part), (1...7).contains(day) {
                result.insert(day)
            }
        }
        return result
    }

    static func nonNegativeInt(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces)).flatMap { $0 >= 0 ? $0 : nil }
    }

    static func rateOK(_ f: NotificationSettingsForm) -> Bool { f.rate.nonBlank == nil || nonNegativeInt(f.rate) != nil }

    /// Threshold / window may stay blank only when the server had no value.
    static func requiredNumberOK(_ text: String, baseline: String) -> Bool {
        text.nonBlank == nil ? baseline.nonBlank == nil : nonNegativeInt(text) != nil
    }

    static func isValid(_ f: NotificationSettingsForm, base: NotificationSettingsForm) -> Bool {
        rateOK(f) && requiredNumberOK(f.threshold, baseline: base.threshold)
            && requiredNumberOK(f.window, baseline: base.window) && (!f.quietEnabled || !f.days.isEmpty)
    }

    /// PATCH body with the changes only; quiet times/days all sent when enabling and the server lacked any of them.
    static func update(_ f: NotificationSettingsForm, base b: NotificationSettingsForm, present: Set<String>) -> HC2SettingsInput {
        let sendQuietAll = f.quietEnabled && quietKeys.contains { !present.contains($0) }
        let rate = f.rate.nonBlank == nil ? nonNegativeInt(b.rate).map { _ in 0 } : nonNegativeInt(f.rate)
        let threshold = nonNegativeInt(f.threshold)
        let window = nonNegativeInt(f.window)
        return HC2SettingsInput(
            quietEnabled: f.quietEnabled != b.quietEnabled ? f.quietEnabled : nil,
            quietFrom: sendQuietAll || f.from != b.from ? f.from : nil,
            quietTo: sendQuietAll || f.to != b.to ? f.to : nil,
            quietDays: sendQuietAll || f.days != b.days ? f.days.sorted().map(String.init).joined(separator: ",") : nil,
            ratePerHour: rate != nonNegativeInt(b.rate) ? rate : nil,
            batchThreshold: threshold != nonNegativeInt(b.threshold) ? threshold : nil,
            batchWindowSeconds: window != nonNegativeInt(b.window) ? window : nil)
    }
}
