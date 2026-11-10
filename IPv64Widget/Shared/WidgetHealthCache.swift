import Foundation
import CryptoKit

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

    static func write(checks: [WidgetCheck]) {
        guard let account = accountFingerprint(),
              let data = try? JSONEncoder().encode(WidgetHealthCachePayload(account: account, checks: checks, updatedAt: .now)),
              let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(data, forKey: cacheKey)
        defaults.set(UUID().uuidString, forKey: revisionKey)
    }

    static func invalidate() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.removeObject(forKey: cacheKey)
        defaults.removeObject(forKey: "HealthCheckCache_Data_v1")
        defaults.set(UUID().uuidString, forKey: revisionKey)
    }
}
