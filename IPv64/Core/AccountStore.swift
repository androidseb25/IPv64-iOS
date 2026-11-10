import Foundation
import Observation
import WidgetKit

/// A locally stored account (Android `User`, spec 01 §3.3). Username/Information are local labels only.
/// JSON keys stay those of the existing iOS data (`uuid`, `Username`, `ApiKey`, `Information`); `id` is read too.
nonisolated struct Account: Codable, Hashable, Identifiable, Sendable {
    /// Placeholder for entries without (valid) id; `withUniqueIds` replaces it.
    static let missingID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    var id: UUID
    var username: String
    var apiKey: String
    var information: String

    init(id: UUID = UUID(), username: String, apiKey: String, information: String = "") {
        self.id = id
        self.username = username
        self.apiKey = apiKey
        self.information = information
    }

    /// Android `User.current` reads an empty Information as "No Information".
    var displayInformation: String { information.isEmpty ? String(localized: "No Information") : information }

    enum CodingKeys: String, CodingKey {
        case uuid, id
        case username = "Username", apiKey = "ApiKey", information = "Information"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawID = (try? c.decodeIfPresent(String.self, forKey: .uuid)) ?? (try? c.decodeIfPresent(String.self, forKey: .id))
        id = rawID.flatMap(UUID.init(uuidString:)) ?? Self.missingID
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        information = try c.decodeIfPresent(String.self, forKey: .information) ?? ""
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString, forKey: .uuid)
        try c.encode(username, forKey: .username)
        try c.encode(apiKey, forKey: .apiKey)
        try c.encode(information, forKey: .information)
    }
}

/// Android `AccountRemoval` result.
nonisolated enum RemovalResult: Equatable, Sendable {
    case removed
    case switchedTo(Account)
    case loggedOut
    case notFound
}

/// Android `removalDecision(list, activeKey, id)` (spec 01 §3.4). Pure.
nonisolated func removalDecision(_ list: [Account], activeKey: String, id: UUID)
    -> (remaining: [Account], activeKey: String, result: RemovalResult) {
    guard let removed = list.first(where: { $0.id == id }) else { return (list, activeKey, .notFound) }
    let remaining = list.filter { $0.id != id }
    if activeKey.isEmpty || removed.apiKey != activeKey || remaining.contains(where: { $0.apiKey == activeKey }) {
        return (remaining, activeKey, .removed)
    }
    guard let next = remaining.first else { return (remaining, "", .loggedOut) }
    return (remaining, next.apiKey, .switchedTo(next))
}

/// Android `withUniqueIds`: missing or duplicate ids get a new UUID (first occurrence keeps its id).
nonisolated func withUniqueIds(_ list: [Account]) -> (list: [Account], repaired: Bool) {
    var seen = Set<UUID>()
    var repaired = false
    let result = list.map { account -> Account in
        var account = account
        if account.id == Account.missingID || seen.contains(account.id) {
            account.id = UUID()
            repaired = true
        }
        seen.insert(account.id)
        return account
    }
    return (result, repaired)
}

/// "Default User", then "Default User 1", "Default User 2", … – the first name no account uses yet.
nonisolated func nextDefaultUsername(_ accounts: [Account]) -> String {
    var username = "Default User"
    var i = 1
    while accounts.contains(where: { $0.username == username }) {
        username = "Default User \(i)"
        i += 1
    }
    return username
}

/// Verbatim Android texts of the account removal flow (spec 01 §3.4).
nonisolated enum AccountRemovalText {
    static func confirm(_ account: Account, accounts: [Account], activeKey: String) -> String {
        let base = String(localized: "\"\(account.username)\" will only be removed from this device. The account and its API key stay valid on ipv64.net, and you can add it again at any time. Push notifications for this account keep arriving on this device until you delete its device channel under Channels (do this before removing).")
        guard account.apiKey == activeKey else { return base }
        if let next = accounts.first(where: { $0.id != account.id }) {
            return base + "\n\n" + String(localized: "This is the active account. The app will switch to \"\(next.username)\".")
        }
        return base + "\n\n" + String(localized: "This is the last account. You will be logged out.")
    }

    static func message(_ result: RemovalResult, name: String) -> String? {
        switch result {
        case .removed: String(localized: "\"\(name)\" removed from this app.")
        case .switchedTo(let next): String(localized: "\"\(name)\" removed. Switched to account \"\(next.username)\".")
        case .loggedOut: String(localized: "\"\(name)\" removed. You have been logged out.")
        case .notFound: nil
        }
    }
}

/// All accounts + the active API key. Keychain (service `net.ipv64.credentials`): `API_KEY` = active key,
/// `USER_ACCOUNTS` = JSON list, `API_KEY_WIDGET` = key the widget uses (kept equal to the active key).
@Observable
final class AccountStore {
    private(set) var accounts: [Account] = []
    /// Active account's API key; "" = logged out (Android pref `APIKEY`).
    private(set) var activeKey: String = ""
    /// Keychain failure text (device locked etc.), shown by the root view.
    var storageError: String?

    private enum Key {
        static let apiKey = "API_KEY", widgetKey = "API_KEY_WIDGET", accounts = "USER_ACCOUNTS"
        static let backup = "USER_ACCOUNTS_BACKUP"
    }

    init() {
        migrateLegacyDefaults()
        do {
            activeKey = try SecureStore.readString(Key.apiKey)
            accounts = try loadAccounts()
            // Android User.init legacy migration: a key without any account becomes "Default User".
            if !activeKey.isEmpty && accounts.isEmpty {
                try save([Account(username: "Default User", apiKey: activeKey)])
            }
            if try SecureStore.readString(Key.widgetKey) != activeKey { syncWidgetKey() }
        } catch {
            storageError = error.localizedDescription
        }
    }

    /// Android `User.current`.
    var current: Account? { accounts.first { $0.apiKey == activeKey && !activeKey.isEmpty } }

    func isActive(_ account: Account) -> Bool { !activeKey.isEmpty && account.apiKey == activeKey }

    func account(id: UUID) -> Account? { accounts.first { $0.id == id } }

    // MARK: Login (spec 01 §3.2)

    enum LoginOutcome { case alreadyAdded, added, activated }

    /// Android login action. `isFromUser` = added from the Users list (does not switch the active account).
    func login(apiKey: String, isFromUser: Bool) -> LoginOutcome {
        let exists = accounts.contains { $0.apiKey == apiKey }
        if exists && isFromUser { return .alreadyAdded }
        if !exists {
            persist(accounts + [Account(username: nextDefaultUsername(accounts), apiKey: apiKey)])
        }
        guard !isFromUser else { return .added }
        setActiveKey(apiKey)
        return .activated
    }

    // MARK: Switch / edit / remove / logout

    /// Android AccountDetailView row tap.
    func activate(_ account: Account) { setActiveKey(account.apiKey) }

    /// Android `User.update()`: replace by id; empty Information is stored as "No Information".
    func update(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        var account = account
        if account.information.isEmpty { account.information = String(localized: "No Information") }
        var list = accounts
        list[index] = account
        persist(list)
    }

    /// Android `User.remove(id)`: local only; also forgets the account's direct node access.
    @discardableResult
    func remove(id: UUID) -> RemovalResult {
        let decision = removalDecision(accounts, activeKey: activeKey, id: id)
        guard decision.result != .notFound else { return .notFound }
        persist(decision.remaining)
        LocalNodeStore.removeOwner(id.uuidString)
        if decision.activeKey != activeKey { setActiveKey(decision.activeKey) }
        return decision.result
    }

    /// Android Logout: clears only the active key; the account entry stays.
    func logout() { setActiveKey("") }

    // MARK: Persistence

    private func setActiveKey(_ key: String) {
        guard key != activeKey else { return }
        do {
            if key.isEmpty { try SecureStore.remove(Key.apiKey) } else { try SecureStore.write(Data(key.utf8), account: Key.apiKey) }
            activeKey = key
            syncWidgetKey()
        } catch {
            storageError = error.localizedDescription
        }
    }

    private func persist(_ list: [Account]) {
        do { try save(list) } catch { storageError = error.localizedDescription }
    }

    private func save(_ list: [Account]) throws {
        try SecureStore.write(try JSONEncoder().encode(list), account: Key.accounts)
        accounts = list
    }

    private func loadAccounts() throws -> [Account] {
        guard let data = try SecureStore.read(Key.accounts), !data.isEmpty else { return [] }
        guard let decoded = try? JSONDecoder().decode([Account].self, from: data) else {
            // Android: keep the corrupt raw value once, then start empty.
            if try SecureStore.read(Key.backup) == nil { try SecureStore.write(data, account: Key.backup) }
            return []
        }
        let (list, repaired) = withUniqueIds(decoded)
        if repaired { try save(list) }
        return list
    }

    /// The widget reads `API_KEY_WIDGET`; keep it on the active account and drop its cached checks.
    private func syncWidgetKey() {
        do {
            if activeKey.isEmpty { try SecureStore.remove(Key.widgetKey) } else { try SecureStore.write(Data(activeKey.utf8), account: Key.widgetKey) }
        } catch {
            storageError = error.localizedDescription
        }
        if let defaults = UserDefaults(suiteName: AppConfig.appGroup) {
            defaults.removeObject(forKey: "HealthCheckCache_Data_v2")
            defaults.removeObject(forKey: "HealthCheckCache_Data_v1")
            defaults.set(UUID().uuidString, forKey: "HealthCheckCache_Revision")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// App versions before 2.0 kept credentials in app-group UserDefaults; move them to the Keychain once.
    private func migrateLegacyDefaults() {
        guard let defaults = UserDefaults(suiteName: AppConfig.appGroup) else { return }
        do {
            for key in [Key.apiKey, Key.widgetKey, Key.accounts] {
                let legacy = key == Key.accounts ? defaults.data(forKey: key) : defaults.string(forKey: key).map { Data($0.utf8) }
                guard let legacy else { continue }
                if try SecureStore.read(key) == nil { try SecureStore.write(legacy, account: key) }
                defaults.removeObject(forKey: key)
            }
        } catch {
            storageError = error.localizedDescription
        }
    }
}
