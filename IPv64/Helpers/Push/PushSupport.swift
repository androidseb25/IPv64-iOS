import SwiftUI
import IPv64

/// What the push code needs from the app: SecNtfy configuration, the active account's API client and a few helpers.

nonisolated enum AppConfig {
    static let appGroup = "group.ipv64.net"
    static let secNtfyURL = "https://api.secntfy.app"
    /// Name in a node's audit log for changes made from this app (`Node64.Configuration.agentActor`).
    static let nodeAgentActor = "IPv64 iOS"

    /// iOS SecNtfy app key: Info.plist `SECNTFY_APP_KEY` (file IPv64-net-Info.plist).
    static var secNtfyAppKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SECNTFY_APP_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isSecNtfyConfigured: Bool { !secNtfyAppKey.isEmpty }
}

/// API v2 client of the active account (IPv64-SPM); the rest of the app still uses `ApiService`.
@Observable
final class Session {
    var apiKey: String { UserStorage.shared.ApiKey.trimmingCharacters(in: .whitespacesAndNewlines) }
    var api: IPv64 { IPv64(apiKey: apiKey) }

    enum IPFamilyChoice { case v4, v6 }

    /// Public IPv4 / IPv6 of this device (`meta.ip()` on ipv4./ipv6.ipv64.net), `nil` if the family is unreachable.
    func myIP(_ family: IPFamilyChoice) async -> String? {
        let host = family == .v4 ? "https://ipv4.ipv64.net/api/v2" : "https://ipv6.ipv64.net/api/v2"
        let client = IPv64(configuration: .init(apiKey: nil, baseURL: URL(string: host)!, timeoutInterval: 5))
        guard let result = try? await client.meta.ip() else { return nil }
        if let reported = result.family, reported != (family == .v4 ? .ipv4 : .ipv6) { return nil }
        return result.ip?.trimmingCharacters(in: .whitespacesAndNewlines).nonBlank
    }
}

/// On a 429 with a short `retryAfter` wait and run once more (Android `ipv64Retrying`).
func ipv64Retrying<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch let error as IPv64Error {
        var wait = 3
        if case .api(let problem) = error, let seconds = problem.retryAfter { wait = seconds }
        guard error.statusCode == 429, wait <= 5 else { throw error }
        try await Task.sleep(for: .seconds(max(wait, 1)))
        return try await operation()
    }
}

struct ErrorText: Identifiable {
    let id = UUID()
    var title: String
    var message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    /// Shows the server's detail text instead of a generic connection error.
    init(_ error: any Error) {
        title = String(localized: "Error")
        if case .api(let problem)? = error as? IPv64Error {
            message = problem.detail
        } else {
            message = error.localizedDescription
        }
    }
}

extension View {
    func errorAlert(_ error: Binding<ErrorText?>) -> some View {
        alert(error.wrappedValue?.title ?? "", isPresented: Binding(
            get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error.wrappedValue?.message ?? "")
        }
    }
}

extension String {
    /// `nil` for empty or whitespace-only text.
    nonisolated var nonBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
