import Foundation
import IPv64

/// Build-time configuration (Android: BuildConfig + LaunchActivity defaults, spec 01 §2.1 / §8).
nonisolated enum AppConfig {
    static let appGroup = "group.ipv64.net"
    static let nodeAgentActor = "IPv64 iOS"
    static let plansURL = URL(string: "https://ipv64.net/pricing")!

    /// Debug-only mock server (`-MOCK_API http://localhost:8064` or env `MOCK_API`); Release ignores it.
    static let mockBase: String? = {
        #if DEBUG
        let raw = ProcessInfo.processInfo.environment["MOCK_API"]
            ?? UserDefaults.standard.string(forKey: "MOCK_API")
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var base = raw.trimmingCharacters(in: .whitespaces)
        while base.hasSuffix("/") { base.removeLast() }
        return base
        #else
        return nil
        #endif
    }()

    /// Android `apiBase(default)`.
    static func apiBase(_ production: URL) -> URL {
        guard let mockBase, let url = URL(string: mockBase + "/api/v2") else { return production }
        return url
    }

    static var cloudBaseURL: URL { apiBase(IPv64.Configuration.productionBaseURL) }
    static var myIPv4BaseURL: URL { apiBase(URL(string: "https://ipv4.ipv64.net/api/v2")!) }
    static var myIPv6BaseURL: URL { apiBase(URL(string: "https://ipv6.ipv64.net/api/v2")!) }

    static var secNtfyURL: String {
        if let mockBase { return mockBase + "/secntfy" }
        return "https://api.secntfy.app"
    }

    /// iOS SecNtfy app key from Info.plist `SECNTFY_APP_KEY` (empty until the owner registers the iOS app at SecNtfy).
    static var secNtfyAppKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SECNTFY_APP_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Android `isSecNtfyConfigured`.
    static var isSecNtfyConfigured: Bool { !secNtfyURL.isEmpty && !secNtfyAppKey.isEmpty }
}
