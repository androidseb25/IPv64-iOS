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
}
