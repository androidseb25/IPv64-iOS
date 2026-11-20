import Foundation
import IPv64

/// Shared by the app and the widget extension (target membership exception).
nonisolated enum AppConfig {
    static let appGroup = "group.ipv64.net"
    /// CloudKit container of the node list the Apple TV app reads (`NodeCloudStore`).
    static let cloudContainer = "iCloud.de.rpicloud.IPv64"
    /// Debug only: `MOCK_API=http://localhost:8064` (environment or launch argument `-MOCK_API …`)
    /// sends every cloud call to `<mock>/api/v2` and SecNtfy to `<mock>/secntfy`. Release builds ignore it.
    static let mockBase: String? = {
        #if DEBUG
        let raw = ProcessInfo.processInfo.environment["MOCK_API"] ?? UserDefaults.standard.string(forKey: "MOCK_API")
        guard var base = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !base.isEmpty else { return nil }
        while base.hasSuffix("/") { base.removeLast() }
        return base
        #else
        return nil
        #endif
    }()

    static var secNtfyURL: String { mockBase.map { $0 + "/secntfy" } ?? "https://api.secntfy.app" }

    /// Cloud API v2 client; `production` is the real host (e.g. ipv4.ipv64.net for my-IP), replaced by the mock.
    static func cloudClient(apiKey: String?, production: String = "https://ipv64.net/api/v2",
                            timeout: TimeInterval = 30) -> IPv64 {
        let base = mockBase.map { $0 + "/api/v2" } ?? production
        return IPv64(configuration: .init(apiKey: apiKey, baseURL: URL(string: base)!, timeoutInterval: timeout))
    }
    /// Name in a node's audit log for changes made from this app (`Node64.Configuration.agentActor`).
    #if os(tvOS)
    static let nodeAgentActor = "IPv64 tvOS"
    #else
    static let nodeAgentActor = "IPv64 iOS"
    #endif
    /// WidgetKit kinds of the DNS64 widget and Control (reloaded by the app after pause/resume).
    static let dns64WidgetKind = "DNS64Widget"
    static let dns64ControlKind = "DNS64BlockingControl"

    /// iOS SecNtfy app key: Info.plist `SECNTFY_APP_KEY` (file IPv64-net-Info.plist).
    static var secNtfyAppKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SECNTFY_APP_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isSecNtfyConfigured: Bool { !secNtfyAppKey.isEmpty }
}
