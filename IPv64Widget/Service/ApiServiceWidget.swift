import Foundation

@MainActor
final class ApiServiceWidget {
    func GetHealthchecks() async -> HealthCheckResult? {
        do {
            let token = try SecureStore.readString("API_KEY_WIDGET")
            guard !token.isEmpty else { return nil }
            let data = try await APITransport.data(
                url: URL(string: "https://ipv64.net/api.php?get_healthchecks&events")!, token: token)
            guard token == (try SecureStore.readString("API_KEY_WIDGET")) else { return nil }
            return try JSONDecoder().decode(HealthCheckResult.self, from: data)
        } catch {
            return nil
        }
    }
}
