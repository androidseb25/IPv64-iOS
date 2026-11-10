import Foundation
import Observation
import IPv64

/// App-wide state: accounts, the cloud client of the active account, public my-IP clients and the lock.
/// One instance, owned by `IPv64App`, injected with `.environment(session)`.
@Observable
final class Session {
    let accounts = AccountStore()

    /// Cloud client of the active account (rebuilt on key change). Without a key every
    /// authenticated call throws `IPv64Error.missingAPIKey` (→ "Authorization failed!").
    private(set) var api: IPv64

    /// Public clients without key; the host names only resolve to A / AAAA so they force the family.
    let myIPv4 = IPv64(configuration: .init(apiKey: nil, baseURL: AppConfig.myIPv4BaseURL, timeoutInterval: 5))
    let myIPv6 = IPv64(configuration: .init(apiKey: nil, baseURL: AppConfig.myIPv6BaseURL, timeoutInterval: 5))

    /// Bumped whenever the active account changes; screens use it in `.task(id:)` to reload.
    private(set) var accountRevision = 0

    /// Android pref `LOCKSCREEN_ENABLED` (existing iOS key `ENABLLE_LOCKSCREEN`, typo kept for migration).
    var lockscreenEnabled: Bool {
        didSet { Self.defaults?.set(lockscreenEnabled, forKey: Self.lockKey) }
    }
    /// The lock overlay is shown while `true`; cold start is locked when the lockscreen is enabled.
    var isLocked: Bool

    private static let lockKey = "ENABLLE_LOCKSCREEN"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: AppConfig.appGroup) }

    init() {
        let enabled = Self.defaults?.bool(forKey: Self.lockKey) ?? false
        lockscreenEnabled = enabled
        isLocked = enabled
        api = Self.makeClient(key: "")
        api = Self.makeClient(key: accounts.activeKey)
    }

    var isLoggedIn: Bool { !accounts.activeKey.isEmpty }

    /// Trimmed active key (Android `IPv64Client.get` trims), "" when logged out.
    var apiKey: String { accounts.activeKey.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: Account actions (all key changes go through here so the client follows)

    func login(apiKey: String, isFromUser: Bool) -> AccountStore.LoginOutcome {
        defer { keyChanged() }
        return accounts.login(apiKey: apiKey, isFromUser: isFromUser)
    }

    func activate(_ account: Account) {
        accounts.activate(account)
        keyChanged()
    }

    @discardableResult
    func removeAccount(id: UUID) -> RemovalResult {
        let result = accounts.remove(id: id)
        if result == .loggedOut { lockscreenEnabled = false }
        keyChanged()
        return result
    }

    /// Android Logout: clears the active key and turns the lockscreen off; accounts, push scope and nodes stay.
    func logout() {
        accounts.logout()
        lockscreenEnabled = false
        keyChanged()
    }

    private func keyChanged() {
        guard api.configuration.apiKey != Self.normalized(accounts.activeKey) else { return }
        api = Self.makeClient(key: accounts.activeKey)
        accountRevision += 1
    }

    private static func normalized(_ key: String) -> String? {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    private static func makeClient(key: String) -> IPv64 {
        IPv64(configuration: .init(apiKey: normalized(key), baseURL: AppConfig.cloudBaseURL))
    }

    // MARK: My IP (Android `myIp(family)`)

    enum IPFamilyChoice { case v4, v6 }

    /// Public IP of this device for one family, `nil` on any error or timeout (5 s).
    func myIP(_ family: IPFamilyChoice) async -> String? {
        let client = family == .v4 ? myIPv4 : myIPv6
        guard let result = try? await client.meta.ip() else { return nil }
        if let reported = result.family, reported != (family == .v4 ? .ipv4 : .ipv6) { return nil }
        return result.ip?.trimmingCharacters(in: .whitespacesAndNewlines).nonBlank
    }
}
