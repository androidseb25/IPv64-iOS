import Foundation
import CryptoKit

/// Pure helpers of the security screens (spec 04 §10–12). Callable from any isolation.
nonisolated enum SecurityLogic {
    /// Android `countryFlag`: two ASCII letters → regional indicator pair, anything else unchanged.
    static func countryFlag(_ code: String?) -> String? {
        guard let code else { return nil }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let scalars = Array(trimmed.unicodeScalars)
        guard scalars.count == 2, scalars.allSatisfy({ $0.value >= 65 && $0.value <= 90 }) else { return code }
        var flag = ""
        for scalar in scalars {
            flag.unicodeScalars.append(Unicode.Scalar(0x1F1E6 + scalar.value - 65)!)
        }
        return flag
    }

    // MARK: Password check (SHA-1 k-anonymity)

    /// 40 uppercase hex characters of SHA-1(UTF-8 password).
    static func sha1Hex(_ password: String) -> String {
        Insecure.SHA1.hash(data: Data(password.utf8)).map { String(format: "%02X", $0) }.joined()
    }

    /// Only `prefix` (5 chars) ever leaves the device.
    static func prefixAndSuffix(_ password: String) -> (prefix: String, suffix: String) {
        let hash = sha1Hex(password)
        return (String(hash.prefix(5)), String(hash.dropFirst(5)))
    }

    /// Count of the line with our suffix (case-insensitive), 0 if absent.
    static func count(forSuffix suffix: String, in entries: [(suffix: String, count: Int)]) -> Int {
        let wanted = suffix.uppercased()
        return entries.first { $0.suffix.uppercased() == wanted }?.count ?? 0
    }

    // MARK: IP input

    static func normalizeIpInput(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 2, trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    static func isValidIPv4(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard (1...3).contains(part.count), part.allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
            if part.count > 1, part.hasPrefix("0") { return false }
            return Int(part).map { $0 <= 255 } ?? false
        }
    }

    static func isValidIPv6(_ text: String) -> Bool {
        guard text.contains(":"), !text.contains(":::"), !text.contains("%") else { return false }
        let halves = text.components(separatedBy: "::")
        guard halves.count <= 2 else { return false }
        func groups(_ part: String) -> [String] { part.isEmpty ? [] : part.components(separatedBy: ":") }
        let head = groups(halves[0])
        let tail = halves.count == 2 ? groups(halves[1]) : []
        let all = head + tail
        var count = 0
        for (index, group) in all.enumerated() {
            if index == all.count - 1, group.contains(".") {
                guard isValidIPv4(group) else { return false }
                count += 2
            } else {
                guard (1...4).contains(group.count), group.allSatisfy({ $0.isHexDigit && $0.isASCII }) else { return false }
                count += 1
            }
        }
        return halves.count == 2 ? count <= 7 : count == 8
    }

    static func isValidIP(_ text: String) -> Bool { isValidIPv4(text) || isValidIPv6(text) }

    // MARK: Formatting

    /// "2026-10-20" → "20.10."; other shapes unchanged.
    static func shortDay(_ day: String) -> String {
        let parts = day.split(separator: "-")
        return parts.count == 3 ? "\(parts[2]).\(parts[1])." : day
    }

    static func prettyKey(_ key: String) -> String { key.replacingOccurrences(of: "_", with: " ") }

    /// First 8 characters + "…" when longer; "–" when missing.
    static func sensorTitle(_ id: String?) -> String {
        guard let id, !id.isEmpty else { return "–" }
        return id.count > 8 ? String(id.prefix(8)) + "…" : id
    }

    /// Fraction of nodes running the honeypot module (0 when no nodes).
    static func honeypotShare(modules: [[String]]) -> (active: Int, total: Int, fraction: Double) {
        let active = modules.filter { $0.contains { $0.lowercased() == "honeypot" } }.count
        return (active, modules.count, modules.isEmpty ? 0 : Double(active) / Double(modules.count))
    }

    static func listURL(base: String) -> String? {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var base = trimmed
        while base.hasSuffix("/") { base.removeLast() }
        return base + "/ipv64_blocklist_v64.txt"
    }
}
