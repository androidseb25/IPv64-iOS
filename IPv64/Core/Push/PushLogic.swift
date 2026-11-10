import Foundation
import IPv64

/// Pure channel helpers (Android `ChannelFieldViews.kt`, `ChannelItemView.kt`, `PushChannelRegistrar.kt`), spec 04 §5–7.
nonisolated enum ChannelLogic {
    /// Android `parseChannelBool`: "true", "1", "yes", "on".
    static func parseBool(_ raw: String?) -> Bool {
        ["true", "1", "yes", "on"].contains(raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "")
    }

    /// Lower-cased field kind, missing = "text".
    static func kindKey(_ field: HC2ChannelType.Field) -> String {
        let kind = field.kind?.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return kind.isEmpty ? "text" : kind
    }

    /// Secret field (never returned by the server).
    static func isSecret(_ field: HC2ChannelType.Field) -> Bool {
        field.secret == true || kindKey(field) == "password"
    }

    /// Android `toChannelFieldText`.
    static func text(_ value: JSONValue?) -> String {
        switch value {
        case nil, .null?: ""
        case .string(let s)?: s
        case .bool(let b)?: b ? "true" : "false"
        case .number(let n)?: n.rounded() == n && abs(n) < 1e15 ? String(Int64(n)) : String(n)
        case let other?: (try? String(decoding: JSONEncoder().encode(other), as: UTF8.self)) ?? ""
        }
    }

    /// Android `toConfigValue`: bool → JSON bool, number → integer, double or string, else string.
    static func configValue(_ field: HC2ChannelType.Field, _ raw: String) -> JSONValue {
        switch kindKey(field) {
        case "bool": return .bool(parseBool(raw))
        case "number":
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let int = Int64(text) { return .number(Double(int)) }
            if let double = Double(text) { return .number(double) }
            return .string(text)
        default: return .string(raw)
        }
    }

    /// Android `initialChannelFieldValue`.
    static func initialValue(_ field: HC2ChannelType.Field, config: [String: JSONValue]?, isEdit: Bool) -> String {
        guard let key = field.key else { return "" }
        let isBool = kindKey(field) == "bool"
        if isSecret(field) { return isEdit ? "" : field.default ?? "" }
        if isEdit {
            if let existing = config?[key], existing != .null {
                return isBool ? String(parseBool(text(existing))) : text(existing)
            }
            return isBool ? String(parseBool(field.default)) : ""
        }
        return isBool ? String(parseBool(field.default)) : field.default ?? ""
    }

    /// Passwords, multi-line and secret values are sent unchanged, everything else trimmed.
    private static func normalized(_ field: HC2ChannelType.Field, _ raw: String) -> String {
        let kind = kindKey(field)
        return kind == "password" || kind == "textarea" || isSecret(field)
            ? raw : raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Android `buildChannelConfig`. New: blank optional fields omitted. Edit: starts from `base` (unknown keys kept),
    /// secrets only when typed (`touched`) and non-blank, a cleared non-secret field is sent as "", `keepKeys` untouched.
    static func buildConfig(fields: [HC2ChannelType.Field], values: [String: String], touched: Set<String>,
                            base: [String: JSONValue]?, isEdit: Bool, keepKeys: Set<String> = []) -> [String: JSONValue] {
        var map = isEdit ? base ?? [:] : [:]
        for field in fields {
            guard let key = field.key?.nonBlank, !keepKeys.contains(key) else { continue }
            let text = normalized(field, values[key] ?? "")
            let blank = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if kindKey(field) == "bool" {
                map[key] = configValue(field, text)
            } else if isSecret(field) {
                if !blank && (!isEdit || touched.contains(key)) { map[key] = configValue(field, text) } else { map[key] = nil }
            } else if blank {
                if isEdit && !self.text(base?[key]).isEmpty { map[key] = .string("") }
            } else {
                map[key] = configValue(field, text)
            }
        }
        return map
    }

    /// Android `channelFieldError` (`nil` = valid).
    static func fieldError(_ field: HC2ChannelType.Field, value: String, required: Bool) -> String? {
        if kindKey(field) == "bool" { return nil }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return required ? String(localized: "Required") : nil }
        if kindKey(field) == "number" && Double(text) == nil { return String(localized: "Must be a number") }
        return nil
    }

    /// Android `channelTestResultMessage` (title, text).
    static func testResultMessage(_ result: HC2ChannelTestResult) -> (title: String, message: String) {
        if result.sent == true {
            return (String(localized: "Test sent"), String(localized: "The test notification was sent."))
        }
        if result.queuedAtNode == true {
            return (String(localized: "Test queued"), String(localized: "The test notification was queued at the node."))
        }
        return (String(localized: "Test not sent"),
                String(localized: "The server did not send the test notification. Please check the channel settings."))
    }

    /// Android `displayName`: name → typeLabel → type → "Channel #<id>".
    static func displayName(_ channel: HC2Channel) -> String {
        channel.name?.nonBlank ?? channel.typeLabel?.nonBlank ?? channel.type?.rawValue.nonBlank
            ?? String(localized: "Channel #\(channel.id)")
    }

    /// Android `isAwaitingVerification`; without types the mail/SMS types need verification.
    static func isAwaitingVerification(_ channel: HC2Channel, types: [HC2ChannelType]?) -> Bool {
        guard channel.verified != true else { return false }
        if let types {
            return types.first { $0.type == channel.type }?.needsVerification == true
        }
        return channel.type == .ipv64Mail || channel.type == .ipv64SMS
    }

    /// Type icon (spec 04 §5).
    static func systemImage(type: String?) -> String {
        switch type?.lowercased() {
        case "ipv64_mail", "smtp", "email", "mail": "at"
        case "ipv64_sms", "sms": "message"
        case "app": "iphone"
        case "telegram": "paperplane.circle"
        case "discord": "bubble.left.and.bubble.right"
        case "ntfy", "secntfy": "bell.and.waves.left.and.right"
        case "gotify": "bell.badge"
        case "pushover": "bell.circle"
        case "webhook": "arrow.triangle.branch"
        case "slack", "teams", "matrix": "puzzlepiece.extension"
        case nil, "": "questionmark.square.dashed"
        default: "bell.badge"
        }
    }

    /// Android `systemChannelLang()`.
    static var systemLanguage: HC2ChannelLanguage {
        Locale.current.language.languageCode?.identifier == "de" ? .de : .en
    }
}

/// Pure helpers of the hc2 "app" channel of this device (Android `PushChannelRegistrar`).
nonisolated enum PushTokenLogic {
    static let fallbackTokenKey = "device_token"

    static func appType(_ types: [HC2ChannelType]?) -> HC2ChannelType? {
        types?.first { $0.type == .app }
    }

    /// Android `resolveAppTokenKey`.
    static func resolveTokenKey(_ appType: HC2ChannelType?) -> String? {
        let fields = (appType?.fields ?? []).filter { $0.key?.nonBlank != nil }
        let keys = fields.compactMap(\.key)
        for preferred in ["device_token", "devicetoken", "token", "ntfy_token"] {
            if let key = keys.first(where: { $0.lowercased() == preferred }) { return key }
        }
        if let key = keys.first(where: { $0.lowercased().contains("token") }) { return key }
        let textual = fields.filter {
            $0.required == true && ["text", "password", "textarea"].contains(ChannelLogic.kindKey($0))
        }
        return textual.count == 1 ? textual[0].key : nil
    }

    /// Android `tokenKeyFor(channel, appType)`.
    static func tokenKey(for channel: HC2Channel, appType: HC2ChannelType?) -> String {
        resolveTokenKey(appType)
            ?? channel.secretsSet?.first { $0.lowercased().contains("token") }
            ?? channel.config?.keys.sorted().first { $0.lowercased().contains("token") }
            ?? fallbackTokenKey
    }

    /// The non-secret config holds the token (SHA-256 fingerprint of a string value; `key` first, then any value).
    static func configHoldsToken(_ channel: HC2Channel, key: String?, token: String) -> Bool {
        guard let config = channel.config else { return false }
        let fp = PushSetupStore.fingerprint(token)
        func matches(_ value: JSONValue?) -> Bool {
            guard case .string(let s)? = value else { return false }
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && PushSetupStore.fingerprint(trimmed) == fp
        }
        if let key, matches(config.first(where: { $0.key.lowercased() == key.lowercased() })?.value) { return true }
        return config.values.contains(where: matches)
    }

    /// Existing config without the token key (case-insensitive) plus `key: token`.
    static func configWithToken(_ existing: [String: JSONValue]?, key: String, token: String) -> [String: JSONValue] {
        var map = (existing ?? [:]).filter { $0.key.lowercased() != key.lowercased() }
        map[key] = .string(token)
        return map
    }

    /// Android `findThisDeviceChannel`: stored id first, else an app channel whose config holds the token.
    static func findThisDevice(_ channels: [HC2Channel], storedId: Int?, key: String?, token: String?) -> HC2Channel? {
        let apps = channels.filter { $0.type == .app }
        if let storedId, let match = apps.first(where: { $0.id == storedId }) { return match }
        guard let token = token?.nonBlank else { return nil }
        return apps.first { configHoldsToken($0, key: key, token: token) }
    }

    /// The server kept the token key (`secrets_set` or `config`, case-insensitive).
    static func holdsTokenKey(_ channel: HC2Channel, key: String) -> Bool {
        let keys = (channel.secretsSet ?? []) + (channel.config.map { Array($0.keys) } ?? [])
        return keys.contains { $0.lowercased() == key.lowercased() }
    }

    /// Existing app channels, names equal to the typed or default device name first (Android candidate order).
    static func sortedCandidates(_ apps: [HC2Channel], names: [String]) -> [HC2Channel] {
        let wanted = Set(names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        func preferred(_ c: HC2Channel) -> Bool {
            wanted.contains((c.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
        return apps.filter(preferred) + apps.filter { !preferred($0) }
    }
}
