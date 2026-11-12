import Foundation
import IPv64

/// Pure logic of the node screens (Android NodeSupport.kt, NodeLocalView.kt).
nonisolated enum NodesLogic {
    /// Stored / cloud name, else "Node …" + last 4 characters of the id.
    static func nodeName(_ name: String?, nodeId: String) -> String {
        name?.nonBlank ?? "Node …" + String(nodeId.suffix(4))
    }

    /// Remote management label (`off`/`read`/`full`/nil).
    static func remoteLabel(_ remote: String?) -> String {
        switch remote {
        case "off": String(localized: "Off")
        case "read": String(localized: "Read only")
        case "full": String(localized: "Full")
        default: String(localized: "Unknown")
        }
    }

    /// Cloud row meta line: location, "v"+version, "seen …" joined " · ", `nil` when all are missing.
    static func cloudMeta(location: String?, version: String?, lastSeen: Date?) -> String? {
        let parts = [
            location?.nonBlank,
            version?.nonBlank.map { "v" + $0 },
            lastSeen.map { String(localized: "seen \($0.formatted(.relative(presentation: .named)))") },
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Remote: Full" plus " · N conflict(s)".
    static func remoteLine(_ remote: String?, conflicts: Int?) -> String {
        var line = String(localized: "Remote: \(remoteLabel(remote))")
        let count = conflicts ?? 0
        if count > 0 {
            line += " · " + (count == 1 ? String(localized: "1 conflict") : String(localized: "\(count) conflicts"))
        }
        return line
    }

    /// Direct node row subtitle: host of the stored URL, else the URL.
    static func directSubtitle(url: String?) -> String {
        guard let url else { return "" }
        return LocalNodeURL.host(of: url) ?? url
    }

    /// Android: every character of the key must be printable ASCII (`!`…`~`).
    static func isValidApiKey(_ key: String) -> Bool {
        key.unicodeScalars.allSatisfy { (0x21...0x7E).contains($0.value) }
    }

    /// Live warning under the form: none, orange (http on the local network) or red (http over the internet).
    enum InsecureWarning: Equatable, Sendable { case none, local, internet }

    static func insecureWarning(for address: String) -> InsecureWarning {
        guard let url = LocalNodeURL.normalizeLocalNodeUrl(address), url.hasPrefix("http://") else { return .none }
        return LocalNodeURL.isPublicHttp(url) ? .internet : .local
    }
}
