import Foundation

/// Shared by the app and the widget extension (target membership exception).
nonisolated enum AppConfig {
    static let appGroup = "group.ipv64.net"
    static let secNtfyURL = "https://api.secntfy.app"
    /// Name in a node's audit log for changes made from this app (`Node64.Configuration.agentActor`).
    static let nodeAgentActor = "IPv64 iOS"
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
