import Foundation

/// Pure texts of the Proxy64 screens (Android ProxyHostRow / CDN64 stats).
nonisolated enum ProxyLogic {
    enum Tone { case gray, green, orange, red }
    struct Tag: Equatable { var text: String; var tone: Tone }

    /// Limit 0 or missing = unlimited (`nil`).
    static func limit<T: BinaryInteger>(_ value: T?) -> T? { value.flatMap { $0 > 0 ? $0 : nil } }

    static func modeShort(_ mode: Int?) -> String { mode.map { "Mode \($0)" } ?? "Mode ?" }

    static func reachTag(enabled: Bool?, state: String?, ms: Int?) -> Tag {
        let base: (String, Tone) = switch (enabled == false, state) {
        case (true, _): (String(localized: "Disabled"), .gray)
        case (_, "up"): (String(localized: "Up"), .green)
        case (_, "slow"): (String(localized: "Slow"), .orange)
        case (_, "down"): (String(localized: "Down"), .red)
        default: (String(localized: "Enabled"), .gray)
        }
        return Tag(text: base.0 + (ms.map { " · \($0) ms" } ?? ""), tone: base.1)
    }

    static func sslTag(state: String?, daysLeft: Int?) -> Tag? {
        switch state {
        case "ok", "soon":
            let days = daysLeft.map { String(localized: "SSL \($0) days") } ?? String(localized: "SSL ok")
            return Tag(text: days, tone: state == "soon" || (daysLeft ?? 99) < 14 ? .orange : .green)
        case "expired": return Tag(text: String(localized: "SSL expired"), tone: .red)
        case "missing": return Tag(text: String(localized: "SSL missing"), tone: .red)
        case "http": return Tag(text: "HTTP", tone: .gray)
        default: return nil
        }
    }

    static func cdnTag(mode: Int?, edgeCount: Int, up: Int) -> Tag {
        Tag(text: "CDN64 · \(modeShort(mode))" + (edgeCount > 0 ? " · " + String(localized: "\(up)/\(edgeCount) servers") : ""),
            tone: edgeCount > 0 && up == 0 ? .red : .green)
    }

    /// Options as one line, e.g. "WS · Cache · HTTPS forced".
    static func optionsLine(websockets: Bool?, blockExploits: Bool?, cacheAssets: Bool?, forceSSL: Bool?,
                            http2: Bool?, http3: Bool?, hsts: Bool?, accessListID: Int?) -> String? {
        let list = [websockets == true ? "WS" : nil, blockExploits == true ? "Exploits" : nil,
                    cacheAssets == true ? "Cache" : nil, forceSSL == true ? "HTTPS forced" : nil,
                    http2 == true ? "H2" : nil, http3 == true ? "H3" : nil, hsts == true ? "HSTS" : nil,
                    (accessListID ?? 0) > 0 ? String(localized: "Not public") : nil].compactMap { $0 }
        return list.isEmpty ? nil : list.joined(separator: " · ")
    }

    /// `kind → target`; blank parts dropped.
    static func hostSubtitle(kind: String?, scheme: String?, targetHost: String?, targetPort: Int?,
                             redirectTarget: String?) -> String {
        let target = targetHost.map { host in
            (scheme.map { "\($0)://" } ?? "") + (targetPort.map { "\(host):\($0)" } ?? host)
        }
        return [kind, redirectTarget ?? target].compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " → ")
    }

    static func counterLine(requests: Int?, errors: Int?, blocked: Int?) -> String? {
        guard let requests else { return nil }
        var text = String(localized: "\(requests) requests")
        if let errors, errors > 0 { text += " · " + String(localized: "\(errors) errors") }
        if let blocked, blocked > 0 { text += " · " + String(localized: "\(blocked) blocked") }
        return text
    }

    static func serversText(connected: Int, total: Int) -> String {
        total == 0 ? String(localized: "No CDN64 servers") : String(localized: "Servers: \(connected) of \(total) connected")
    }

    // MARK: Host editor

    static func parseNames(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func parsePort(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces)).flatMap { (1...65535).contains($0) ? $0 : nil }
    }

    // MARK: CDN64 modes

    static func cdnModeTitle(_ mode: Int) -> String {
        switch mode {
        case 1: String(localized: "Pass through (default)")
        case 2: String(localized: "Terminate on the servers")
        case 3: String(localized: "Without Node64")
        default: modeShort(mode)
        }
    }

    static func cdnModeDescription(_ mode: Int) -> String {
        switch mode {
        case 1: String(localized: "The servers only pass the encrypted connection through; it is decrypted in your node. The right choice for almost everything.")
        case 2: String(localized: "The servers decrypt (own certificate) and filter there: blocklists, limits, HTTP/3. Good for small uploads. Not with TLS passthrough.")
        case 3: String(localized: "The servers go directly to your target without a tunnel — it must be reachable from the internet. Set up on the website:")
        default: ""
        }
    }

    /// Android `enableCdn64`: error text of the first failed name, else `nil`.
    static func firstEnableError(_ results: [(name: String?, failed: Bool, error: String?, code: String?)]) -> String? {
        results.first(where: \.failed).map { [$0.name, $0.error ?? $0.code].compactMap { $0 }.joined(separator: ": ") }
    }

    static var noNodeError: ErrorText {
        ErrorText(title: String(localized: "No node reachable"),
                  message: String(localized: "No node with Proxy64 is reachable. Check the connection under More → Nodes."))
    }

    // MARK: Numbers

    static func megabytes(_ mb: Double) -> String {
        if mb >= 1024 * 1024 { return String(format: "%.1f TB", locale: .current, mb / (1024 * 1024)) }
        if mb >= 1024 { return String(format: "%.2f GB", locale: .current, mb / 1024) }
        return String(format: "%.1f MB", locale: .current, mb)
    }

    static func fraction(used: Double?, limit: Int?) -> Double? {
        guard let limit, limit > 0 else { return nil }
        return min(max((used ?? 0) / Double(limit), 0), 1)
    }
}
