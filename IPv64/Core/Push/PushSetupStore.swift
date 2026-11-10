import Foundation
import CryptoKit

/// Device-local push setup state (Android `PushSetupStore`, prefs `HC2_PUSH_SETUP`, spec 01 §2.4 / 04 §7.3).
/// Keys (app-group UserDefaults, prefix `HC2_PUSH_SETUP.`): `done_<scope>` Bool, `channel_<scope>` Int,
/// `tokenfp_<scope>` String, `acct_<keyHash>` Int. Scope = `"a" + sha256("account:<id>")[:16]` once the
/// account id is known, else the key hash `sha256(trim(apiKey))[:16]`. The token itself is never stored.
nonisolated enum PushSetupStore {
    private static let prefix = "HC2_PUSH_SETUP."
    /// Test seam: an isolated suite replaces the app-group defaults.
    nonisolated(unsafe) static var overrideDefaults: UserDefaults?
    private static var defaults: UserDefaults { overrideDefaults ?? UserDefaults(suiteName: AppConfig.appGroup) ?? .standard }

    static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Fingerprint of a (trimmed) device token.
    static func fingerprint(_ token: String) -> String {
        sha256Hex(token.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// `nil` when logged out.
    static func keyHash(apiKey: String) -> String? {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : String(sha256Hex(key).prefix(16))
    }

    static func accountScope(accountId: Int) -> String { "a" + sha256Hex("account:\(accountId)").prefix(16) }

    static func accountId(keyHash: String) -> Int? {
        defaults.object(forKey: prefix + "acct_" + keyHash) as? Int
    }

    /// Current scope (Android `accountHash()`), `nil` when logged out.
    static func scope(apiKey: String) -> String? {
        guard let keyHash = keyHash(apiKey: apiKey) else { return nil }
        return accountId(keyHash: keyHash).map(accountScope) ?? keyHash
    }

    /// Android `shouldShow()`: logged in, not done, no device channel stored, SecNtfy configured.
    static func shouldShow(apiKey: String) -> Bool {
        guard let scope = scope(apiKey: apiKey) else { return false }
        return !defaults.bool(forKey: prefix + "done_" + scope)
            && defaults.object(forKey: prefix + "channel_" + scope) == nil
            && AppConfig.isSecNtfyConfigured
    }

    static func markDone(apiKey: String) {
        guard let scope = scope(apiKey: apiKey) else { return }
        defaults.set(true, forKey: prefix + "done_" + scope)
    }

    /// Stored hc2 channel id of this device.
    static func channelId(apiKey: String) -> Int? {
        scope(apiKey: apiKey).flatMap { defaults.object(forKey: prefix + "channel_" + $0) as? Int }
    }

    static func tokenFingerprint(apiKey: String) -> String? {
        scope(apiKey: apiKey).flatMap { defaults.string(forKey: prefix + "tokenfp_" + $0) }
    }

    static func setChannel(apiKey: String, id: Int, tokenFingerprint: String?) {
        guard let scope = scope(apiKey: apiKey) else { return }
        defaults.set(id, forKey: prefix + "channel_" + scope)
        if let tokenFingerprint {
            defaults.set(tokenFingerprint, forKey: prefix + "tokenfp_" + scope)
        } else {
            defaults.removeObject(forKey: prefix + "tokenfp_" + scope)
        }
    }

    static func clearChannel(apiKey: String) {
        guard let scope = scope(apiKey: apiKey) else { return }
        defaults.removeObject(forKey: prefix + "channel_" + scope)
        defaults.removeObject(forKey: prefix + "tokenfp_" + scope)
    }

    /// Remembers the account id of a key hash and migrates key-hash-scoped entries to the account scope
    /// (existing account values win; channel + fingerprint only if the account scope has no channel).
    static func rememberAccountId(keyHash: String, accountId: Int) {
        let account = accountScope(accountId: accountId)
        let d = defaults
        if d.object(forKey: prefix + "channel_" + account) == nil, let channel = d.object(forKey: prefix + "channel_" + keyHash) {
            d.set(channel, forKey: prefix + "channel_" + account)
            if let fp = d.string(forKey: prefix + "tokenfp_" + keyHash) { d.set(fp, forKey: prefix + "tokenfp_" + account) }
        }
        if d.bool(forKey: prefix + "done_" + keyHash) { d.set(true, forKey: prefix + "done_" + account) }
        for field in ["done_", "channel_", "tokenfp_"] { d.removeObject(forKey: prefix + field + keyHash) }
        d.set(accountId, forKey: prefix + "acct_" + keyHash)
    }
}
