#if DEBUG
import Foundation
import OSLog

/// Opt-in simulator fixtures. Release builds contain neither this transport nor its setup.
enum DebugFixtures {
    static func configure() {
        seedMockLogin()
        seedMockNodes()
        guard ProcessInfo.processInfo.arguments.contains("--fixture-api") else { return }
        URLProtocol.registerClass(FixtureURLProtocol.self)
        // A separate non-user key verifies the configured shared Keychain access group.
        do {
            let probe = Data("fixture-probe".utf8)
            try SecureStore.write(probe, account: "FIXTURE_PROBE")
            guard try SecureStore.read("FIXTURE_PROBE") == probe else { return }
            try SecureStore.remove("FIXTURE_PROBE")
            print("FIXTURE: Keychain roundtrip passed")
        } catch { print("FIXTURE: Keychain roundtrip failed") }
        if ProcessInfo.processInfo.arguments.contains("--fixture-migration"),
           (try? SecureStore.readString("API_KEY")) == "",
           UserStorage.sharedDefault?.object(forKey: "USER_ACCOUNTS") == nil {
            UserStorage.sharedDefault?.set("fixture-key", forKey: "API_KEY")
            UserStorage.sharedDefault?.set("fixture-key", forKey: "API_KEY_WIDGET")
            let user = User(Username: "Fixture account", ApiKey: "fixture-key", Information: "Local test data")
            UserStorage.sharedDefault?.set(try? JSONEncoder().encode([user]), forKey: "USER_ACCOUNTS")
        }
    }

    /// `MOCK_LOGIN=<key>` (env, only together with MOCK_API): logs in like LoginView when no account is stored,
    /// for simulators that cannot type.
    private static func seedMockLogin() {
        guard AppConfig.mockBase != nil, let key = ProcessInfo.processInfo.environment["MOCK_LOGIN"], !key.isEmpty,
              UserStorage.shared.ApiKey.isEmpty else { return }
        let storage = UserStorage.shared
        User(Username: "Mock account", ApiKey: key, Information: "").save()
        storage.ApiKey = key
        storage.ApiKeyWidget = key
        storage.ShowWelcomeView = false
        storage.ShowLoginView = false
    }

    /// `MOCK_NODES=nd_a=http://host/node/api,nd_b=…` (env or defaults): direct access to mock nodes
    /// for the logged-in account, so node screens can be tested where the simulator cannot type.
    private static func seedMockNodes() {
        // `MOCK_NODES_CLEAR=nd_a,nd_b` (env): removes seeded mock node access again.
        for id in (ProcessInfo.processInfo.environment["MOCK_NODES_CLEAR"] ?? "").split(separator: ",") {
            LocalNodeStore.remove(String(id))
        }
        let raw = ProcessInfo.processInfo.environment["MOCK_NODES"] ?? UserDefaults.standard.string(forKey: "MOCK_NODES")
        guard let raw, let owner = User.empty.current?.uuid, !owner.isEmpty else { return }
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            try? LocalNodeStore.save(id: parts[0], url: parts[1], key: "node64_mock", owner: owner)
        }
    }
}

nonisolated private final class FixtureURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let query = url.query ?? ""
        let token = request.value(forHTTPHeaderField: "Authorization")
        let (code, object): (Int, [String: Any])
        if url.host?.hasPrefix("ipv4.") == true {
            (code, object) = (200, ["ip": "192.0.2.1", "type": "IPv4"])
        } else if url.host?.hasPrefix("ipv6.") == true {
            (code, object) = (200, ["ip": "2001:db8::1", "type": "IPv6"])
        } else if token != "Bearer fixture-key" {
            (code, object) = (401, ["status": "401"])
        } else if query.contains("get_account_info") {
            var account: [String: Any] = ["account_status": 1, "email": "fixture@example.invalid", "reg_date": "2026-01-01 00:00:00", "update_hash": "fixture", "api_key": "fixture-key", "info": "ok", "status": "200 OK", "get_account_info": "ok"]
            for key in ["dyndns_updates", "dyndns_subdomains", "owndomains", "healthchecks", "healthchecks_updates", "api_updates", "sms_count", "vpn_limit_reached", "vpn_traffic_input", "vpn_traffic_output"] { account[key] = 1 }
            var plan: [String: Any] = ["class_name": "Fixture"]
            for key in ["dyndns_domain_limit", "dyndns_update_limit", "owndomain_limit", "healthcheck_limit", "healthcheck_update_limit", "dyndns_ttl", "api_limit", "sms_limit", "vpn_traffic", "vpn_queue"] { plan[key] = 100 }
            account["account_class"] = plan
            (code, object) = (200, account)
        } else if query.contains("get_domains") {
            var domains: [String: Any] = [:]
            for index in 1...100 {
                domains["server\(index).ipv64.net"] = ["updates": index, "wildcard": 0, "domain_update_hash": "fixture", "records": [["record_id": index, "content": index.isMultiple(of: 2) ? "192.0.2.1" : "192.0.2.2", "type": "A", "ttl": 60, "praefix": "", "last_update": "2026-01-01 00:00:00"]]]
            }
            (code, object) = (200, ["status": "200", "subdomains": domains])
        } else if query.contains("get_healthchecks") {
            var checks: [String: Any] = ["status": "200", "info": "ok"]
            for index in 1...100 {
                checks["check\(index)"] = ["name": "Server \(index)", "healthstatus": (index % 4) + 1, "healthtoken": "fixture-\(index)", "add_time": "2026-01-01 00:00:00", "last_update_time": "2026-01-01 00:00:00", "alarm_time": "2026-01-01 00:15:00", "alarm_down": 1, "alarm_up": 1, "integration_id": "10,21", "alarm_count": 5, "alarm_unit": 1, "grace_count": 1, "grace_unit": 1, "pings_total": index, "type": "push", "events": [["event_time": "2026-01-01 00:00:00", "status": (index % 4) + 1, "text": "Fixture event"]]]
            }
            (code, object) = (200, checks)
        } else if query.contains("get_integrations") {
            var integrations: [String: Any] = ["status": "200"]
            for id in [1, 10, 21] {
                integrations["method\(id)"] = ["integration": "email", "integration_id": id, "integration_name": "Method \(id)", "add_time": "2026-01-01 00:00:00", "last_used": "2026-01-01 00:00:00"]
            }
            (code, object) = (200, integrations)
        } else { (code, object) = (200, ["status": "200", "info": "Fixture response"]) }
        let data = try! JSONSerialization.data(withJSONObject: object)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
#endif
