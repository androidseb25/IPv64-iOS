import Foundation
import IPv64

/// Website endpoint `GET /cdn64o` (not in the SDK): CDN64 names of the account (all modes) and the combined quota.
nonisolated struct Cdn64Overview: Decodable, Sendable {
    var quota: Node64.CDNOnlineQuota?
    var hosts: [Cdn64Host]?

    nonisolated struct Edge: Decodable, Sendable { var name: String? }
    nonisolated struct Traffic: Decodable, Sendable {
        var bytesIn: Int64?, bytesOut: Int64?
        enum CodingKeys: String, CodingKey { case bytesIn = "bytes_in", bytesOut = "bytes_out" }
    }
    nonisolated struct Target: Decodable, Sendable { var target: String?, port: Int? }

    static func load(apiKey: String) async throws -> Cdn64Overview {
        let base = AppConfig.mockBase.map { $0 + "/api/v2" } ?? "https://ipv64.net/api/v2"
        var request = URLRequest(url: URL(string: base + "/cdn64o")!, timeoutInterval: 30)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            struct Problem: Decodable { var detail: String? }
            let detail = (try? JSONDecoder().decode(Problem.self, from: data))?.detail?.nonBlank
            throw ErrorText(title: status == 401 ? String(localized: "Unauthorized") : String(localized: "Error"),
                            message: detail ?? "HTTP \(status)")
        }
        struct Envelope: Decodable { var data: Cdn64Overview? }
        guard let overview = try JSONDecoder().decode(Envelope.self, from: data).data else {
            throw ErrorText(title: String(localized: "Error"), message: String(localized: "Unexpected answer from ipv64.net."))
        }
        return overview
    }
    init() {}
}

nonisolated struct Cdn64Host: Decodable, Sendable, Identifiable {
    var id: Int?
    var fqdn: String?
    var mode: Int?
    var wildcard: Bool?
    var status: String?
    var blockedReason: String?
    var error: String?
    var edges: [Cdn64Overview.Edge]?
    var trafficMonth: Cdn64Overview.Traffic?
    var paused: Bool?
    var target: Cdn64Overview.Target?

    enum CodingKeys: String, CodingKey {
        case id, fqdn, mode, wildcard, status, error, edges, paused, target
        case blockedReason = "blocked_reason", trafficMonth = "traffic_month"
    }
}

extension ErrorText: LocalizedError {
    var errorDescription: String? { message }
}
