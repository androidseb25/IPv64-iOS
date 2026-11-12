import Foundation
import Combine

@MainActor
final class ApiService: ObservableObject {
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private var pendingRequests = 0
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    private func request<T: Decodable>(query: String = "", method: String = "GET",
                                       fields: [String: String] = [:], url: URL? = nil,
                                       token: String? = nil, authenticated: Bool = true,
                                       reportError: Bool = true) async -> T? {
        let accountSession = UserStorage.shared.sessionID
        let credential = authenticated ? (token ?? UserStorage.shared.ApiKey) : nil
        pendingRequests += 1
        isLoading = true
        defer {
            pendingRequests -= 1
            isLoading = pendingRequests > 0
        }
        do {
            try Task.checkCancellation()
            let endpoint = url ?? URL(string: "https://ipv64.net/api.php\(query)")!
            let data = try await APITransport.data(url: endpoint, token: credential, method: method,
                                                   fields: fields, session: session)
            guard accountSession == UserStorage.shared.sessionID else { return nil }
            try Task.checkCancellation()
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if reportError, accountSession == UserStorage.shared.sessionID,
               !Task.isCancelled, !APITransport.isCancellation(error) {
                errorMessage = APITransport.message(for: error)
            }
            return nil
        }
    }

    func GetAccountStatus(token: String? = nil) async -> AccountInfo? {
        await request(query: "?get_account_info", token: token)
    }
    func GetLogs() async -> Logs? { await request(query: "?get_logs") }
    func GetMyIp(_ onlyV4: Bool = true) async -> MyIP? {
        await request(url: URL(string: "https://\(onlyV4 ? "ipv4" : "ipv6").ipv64.net/update.php?howismyip")!,
                      authenticated: false, reportError: false)
    }
    func GetDomains() async -> DomainResult? { await request(query: "?get_domains") }
    func PostDomain(domain: String) async -> AddDomainResult? {
        await request(method: "POST", fields: ["add_domain": domain])
    }
    func DeleteDNSRecord(recordId: Int) async -> AddDomainResult? {
        await request(method: "DELETE", fields: ["del_record": String(recordId)])
    }
    func UpdateDNSRecord(urlDNSUpdate: String) async -> IPUpdateResult? {
        guard let url = URL(string: urlDNSUpdate), url.scheme == "https", url.host == "ipv64.net" else {
            errorMessage = "The update URL is invalid."
            return nil
        }
        return await request(url: url, authenticated: false)
    }
    func DeleteDomain(domain: String) async -> AddDomainResult? {
        await request(method: "DELETE", fields: ["del_domain": domain])
    }
    func PostDNSRecord(domain: String, praefix: String, typ: String, content: String) async -> AddDomainResult? {
        await request(method: "POST", fields: ["add_record": domain, "praefix": praefix, "type": typ, "content": content])
    }
    func GetHealthchecks() async -> HealthCheckResult? { await request(query: "?get_healthchecks&events") }
    func PostStartPauseHealthcheck(startPause: String, hcToken: String) async -> AddDomainResult? {
        await request(method: "POST", fields: [startPause: hcToken])
    }
    func PostHealthcheck(add_healthcheck: String, alarm_count: Int, alarm_unit: Int) async -> AddDomainResult? {
        await request(method: "POST", fields: ["add_healthcheck": add_healthcheck,
                                               "alarm_count": String(alarm_count), "alarm_unit": String(alarm_unit)])
    }
    func DeleteHealthcheck(hcToken: String) async -> AddDomainResult? {
        await request(method: "DELETE", fields: ["del_healthcheck": hcToken])
    }
    func PostEditHealthcheck(healthcheck: HealthCheck) async -> AddDomainResult? {
        await request(method: "POST", fields: ["edit_healthcheck": healthcheck.healthtoken,
            "healthcheck_name": healthcheck.name, "alarm_count": String(healthcheck.alarm_count),
            "alarm_unit": String(healthcheck.alarm_unit), "integration": healthcheck.integration_id,
            "grace_count": String(healthcheck.grace_count), "grace_unit": String(healthcheck.grace_unit),
            "alarm_down": String(healthcheck.alarm_down), "alarm_up": String(healthcheck.alarm_up)])
    }
}
