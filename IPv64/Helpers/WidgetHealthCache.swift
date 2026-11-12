import Foundation
import CryptoKit

/// What the widget needs of a healthchecks 2.0 check: name plus the state history (newest first, raw `HC2CheckState` values).
nonisolated struct WidgetCheck: Codable, Hashable, Sendable {
    let token: String
    let name: String
    let states: [String]
}

nonisolated struct WidgetHealthCachePayload: Codable, Sendable {
    let account: String
    let checks: [WidgetCheck]
    let updatedAt: Date
}

nonisolated enum WidgetHealthCacheStore {
    static let suiteName = "group.ipv64.net"
    static let cacheKey = "HealthCheckCache_Data_v2"
    static let revisionKey = "HealthCheckCache_Revision"

    static func accountFingerprint() -> String? {
        guard let key = try? SecureStore.readString("API_KEY_WIDGET"), !key.isEmpty else { return nil }
        return SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func invalidate() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.removeObject(forKey: cacheKey)
        defaults.removeObject(forKey: "HealthCheckCache_Data_v1")
        defaults.set(UUID().uuidString, forKey: revisionKey)
    }
}
