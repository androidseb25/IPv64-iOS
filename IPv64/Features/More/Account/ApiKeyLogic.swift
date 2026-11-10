import Foundation
import IPv64

nonisolated enum ApiKeyText {
    static func subtitle(_ key: APIKey, current: Bool) -> String {
        var lines: [String] = []
        if let hint = key.tokenHint?.nonBlank { lines.append(hint) }
        if let created = Formatters.realOrNil(key.createdAt) { lines.append(String(localized: "Created \(Formatters.germanTime(created))")) }
        if let expires = Formatters.realOrNil(key.expiresAt) {
            lines.append(String(localized: "Expires \(Formatters.germanTime(expires))"))
        } else {
            lines.append(String(localized: "Never expires"))
        }
        lines.append(String(localized: "\(key.uses ?? 0) calls"))
        if current { lines.append(String(localized: "This app uses this key and cannot delete it.")) }
        return lines.joined(separator: "\n")
    }

    /// Validity choices of the create sheet (seconds, 0 = unlimited).
    static let validity: [(label: String, seconds: Int)] = [
        (String(localized: "Unlimited"), 0), (String(localized: "1 day"), 86_400),
        (String(localized: "7 days"), 7 * 86_400), (String(localized: "30 days"), 30 * 86_400),
        (String(localized: "90 days"), 90 * 86_400), (String(localized: "1 year"), 31_536_000),
    ]
    static let defaultValidity = 30 * 86_400
    static let nameLimit = 64
}
