import Foundation

/// Pure CDN64 / Proxy64 logic (spec 03 §1–5, §10): quota conversion, chip texts, validation, mode texts.
/// Primitive inputs only, so tests can call it from any isolation.
nonisolated enum ProxyLogic {
    // MARK: Stats card (spec 03 §2)

    struct Stats: Equatable {
        var domains: String
        var domainFraction: Double?
        var domainHint: String?
        var traffic: String
        var trafficFraction: Double?
        var trafficHint: String?
    }

    /// GB → "114.5 MB" / "1.20 GB" / "20.0 TB".
    static func gbText(_ gb: Double) -> String {
        if gb >= 1024 { return String(format: "%.1f TB", locale: .current, gb / 1024) }
        if gb >= 1 { return String(format: "%.2f GB", locale: .current, gb) }
        return String(format: "%.1f MB", locale: .current, gb * 1024)
    }

    /// Month forecast; `nil` early in the month or without usage.
    static func forecastGB(used: Double, now: Date = .now, calendar: Calendar = .current) -> Double? {
        let parts = calendar.dateComponents([.day, .hour], from: now)
        let day = Double((parts.day ?? 1) - 1) + Double(parts.hour ?? 0) / 24
        let days = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        return used > 0 && day >= 1 ? used / day * Double(days) : nil
    }

    /// Node quota (traffic in MB, covers old and new CDN).
    static func quotaStats(domainsUsed: Int?, domainsLimit: Int?, oldCDN: Int?, trafficUsedMB: Double?,
                           trafficLimitMB: Int?, bandwidthMbit: Int?, now: Date = .now) -> Stats {
        let usedGB = (trafficUsedMB ?? 0) / 1024
        let limit = domainsLimit.flatMap { $0 > 0 ? $0 : nil }
        let trafficLimit = trafficLimitMB.flatMap { $0 > 0 ? $0 : nil }
        let bandwidth = bandwidthMbit.map { $0 > 0 ? "Bandwidth: \($0) Mbit/s" : "Bandwidth: unlimited" }
        return Stats(
            domains: "\(domainsUsed ?? 0) / \(limit.map(String.init) ?? "∞")",
            domainFraction: limit.map { Double(domainsUsed ?? 0) / Double($0) },
            domainHint: oldCDN.flatMap { $0 > 0 ? "\($0) in the old CDN" : nil },
            traffic: "\(gbText(usedGB)) / \(trafficLimit.map { gbText(Double($0) / 1024) } ?? "∞")",
            trafficFraction: trafficLimit.map { (trafficUsedMB ?? 0) / Double($0) },
            trafficHint: hint(usedGB, bandwidth, now))
    }

    /// Cloud usage (`account.me`, traffic already in GB).
    static func usageStats(domainsUsed: Double?, domainsLimit: Int?, trafficUsedGB: Double?,
                           trafficLimitGB: Int?, now: Date = .now) -> Stats {
        let limit = domainsLimit.flatMap { $0 > 0 ? $0 : nil }
        let trafficLimit = trafficLimitGB.flatMap { $0 > 0 ? $0 : nil }
        let used = trafficUsedGB ?? 0
        return Stats(
            domains: "\(Int(domainsUsed ?? 0)) / \(limit.map(String.init) ?? "∞")",
            domainFraction: limit.map { (domainsUsed ?? 0) / Double($0) },
            domainHint: nil,
            traffic: "\(gbText(used)) / \(trafficLimit.map { gbText(Double($0)) } ?? "∞")",
            trafficFraction: trafficLimit.map { used / Double($0) },
            trafficHint: hint(used, nil, now))
    }

    private static func hint(_ usedGB: Double, _ bandwidth: String?, _ now: Date) -> String? {
        let lines = [forecastGB(used: usedGB, now: now).map { "At this rate: \(gbText($0)) this month" }, bandwidth]
            .compactMap { $0 }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    // MARK: Plan availability (Android FeatureAvailability, CDN)

    enum Availability: Equatable {
        case available, unknown, notInPlan
        case limitReached(used: Int, limit: Int)

        var canCreate: Bool { self == .available || self == .unknown }
    }

    static func availability(counterPresent: Bool, used: Double?, limit: Int?) -> Availability {
        guard counterPresent else { return .unknown }
        guard let limit else { return .available }
        if limit <= 0 { return .notInPlan }
        let usedInt = Int((used ?? 0).rounded(.up))
        return usedInt >= limit ? .limitReached(used: usedInt, limit: limit) : .available
    }

    // MARK: Host chips and lines (spec 03 §3.3)

    enum ChipColor { case gray, green, orange, red, blue }
    struct Chip: Equatable { var text: String; var color: ChipColor }

    static func cdnModeShort(_ mode: Int?) -> String { mode.map { "Mode \($0)" } ?? "Mode ?" }

    static func reachChip(enabled: Bool?, state: String?, ms: Int?) -> Chip {
        let base: (String, ChipColor) = switch (enabled == false, state) {
        case (true, _): ("Disabled", .gray)
        case (_, "up"): ("Up", .green)
        case (_, "slow"): ("Slow", .orange)
        case (_, "down"): ("Down", .red)
        default: ("Enabled", .gray)
        }
        return Chip(text: base.0 + (ms.map { " · \($0) ms" } ?? ""), color: base.1)
    }

    static func sslChip(state: String?, daysLeft: Int?) -> Chip? {
        switch state {
        case "ok", "soon":
            let orange = state == "soon" || (daysLeft ?? 99) < 14
            return Chip(text: "SSL \(daysLeft.map { "\($0) days" } ?? "ok")", color: orange ? .orange : .green)
        case "expired": return Chip(text: "SSL expired", color: .red)
        case "missing": return Chip(text: "SSL missing", color: .red)
        case "http": return Chip(text: "HTTP", color: .gray)
        default: return nil
        }
    }

    static func cdnChip(mode: Int?, edgeCount: Int, up: Int) -> Chip {
        Chip(text: "CDN64 · \(cdnModeShort(mode))" + (edgeCount > 0 ? " · \(up)/\(edgeCount) servers" : ""),
             color: edgeCount > 0 && up == 0 ? .red : .green)
    }

    static func optionChips(websockets: Bool?, blockExploits: Bool?, cacheAssets: Bool?, forceSSL: Bool?,
                            http2: Bool?, http3: Bool?, hsts: Bool?, accessListID: Int?) -> [String] {
        [websockets == true ? "WS" : nil, blockExploits == true ? "Exploits" : nil,
         cacheAssets == true ? "Cache" : nil, forceSSL == true ? "HTTPS forced" : nil,
         http2 == true ? "H2" : nil, http3 == true ? "H3" : nil, hsts == true ? "HSTS" : nil,
         (accessListID ?? 0) > 0 ? "Not public" : nil].compactMap { $0 }
    }

    /// `kind → target` line; blank parts dropped.
    static func hostSubtitle(kind: String?, scheme: String?, targetHost: String?, targetPort: Int?,
                             redirectTarget: String?) -> String {
        let target = targetHost.map { host in
            (scheme.map { "\($0)://" } ?? "") + (targetPort.map { "\(host):\($0)" } ?? host)
        }
        return [kind, redirectTarget ?? target].compactMap { $0 }.filter { !$0.isBlank }.joined(separator: " → ")
    }

    static func counterLine(requests: Int?, errors: Int?, blocked: Int?) -> String? {
        guard let requests else { return nil }
        var text = "\(requests) requests"
        if let errors, errors > 0 { text += " · \(errors) errors" }
        if let blocked, blocked > 0 { text += " · \(blocked) blocked" }
        return text
    }

    // MARK: CDN64 modes (spec 03 §4)

    static func cdnModeLabel(_ mode: Int) -> (title: String, description: String) {
        switch mode {
        case 1: ("Pass through (default)", "The servers only pass the encrypted connection through; it is decrypted in your node. The right choice for almost everything.")
        case 2: ("Terminate on the servers", "The servers decrypt (own certificate) and filter there: blocklists, limits, HTTP/3. Good for small uploads. Not with TLS passthrough.")
        case 3: ("Without Node64", "The servers go directly to your target without a tunnel — it must be reachable from the internet. Set up on the website: ipv64.net/cdn64")
        default: ("Mode \(mode)", "")
        }
    }

    static func cdnModeFlow(_ mode: Int) -> String? {
        switch mode {
        case 1: "Visitor → CDN64 server (reads name only) → tunnel → Node64 (TLS ends here, your certificate) → service"
        case 2: "Visitor → CDN64 server (TLS ends here, blocklists, IP limits) → tunnel → Node64 (request with real visitor IP) → service"
        case 3: "Visitor → CDN64 server (cache, port mapper) → internet → your target"
        default: nil
        }
    }

    // MARK: Host editor validation (spec 03 §5.4), first match wins

    static func parseNames(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func parsePort(_ text: String, range: ClosedRange<Int> = 1...65535) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces)).flatMap { range.contains($0) ? $0 : nil }
    }

    static func hostError(names: [String], isProxy: Bool, isRedirect: Bool, host: String, port: String,
                          redirectTarget: String) -> String? {
        if names.isEmpty { return "Enter at least one domain name." }
        if isProxy && host.isBlank { return "Enter the target host." }
        if isProxy && parsePort(port) == nil { return "The port must be between 1 and 65535." }
        if isRedirect && redirectTarget.isBlank { return "Enter the redirect target." }
        return nil
    }

    // MARK: Access list address (spec 03 §10.1)

    /// Android `isIpv4`: strict dotted quad without leading zeros.
    static func isIPv4(_ s: String) -> Bool {
        s.range(of: #"^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$"#,
                options: .regularExpression) != nil
    }

    /// Android `isIpv6`: numeric IPv6 without zone, IPv4-mapped rejected.
    static func isIPv6(_ s: String) -> Bool {
        guard s.contains(":"), s.count <= 45, !s.contains("%") else { return false }
        var addr = in6_addr()
        guard inet_pton(AF_INET6, s, &addr) == 1 else { return false }
        let b = withUnsafeBytes(of: &addr) { Array($0) }
        return !(b[0..<10].allSatisfy { $0 == 0 } && b[10] == 0xFF && b[11] == 0xFF)
    }

    /// `nil` = valid.
    static func addressError(_ input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "Enter an IP address or network." }
        let parts = value.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if parts.count > 2 { return "Use the format 203.0.113.0/24 or 2001:db8::/32." }
        let v4 = isIPv4(parts[0])
        if !v4 && !isIPv6(parts[0]) { return "Enter a valid IPv4 or IPv6 address." }
        if parts.count == 2 {
            // Digits only: Int() would accept "+8" and "-0".
            guard !parts[1].isEmpty, parts[1].allSatisfy({ $0 >= "0" && $0 <= "9" }), let prefix = Int(parts[1])
            else { return "The prefix length must be a number." }
            let max = v4 ? 32 : 128
            if prefix > max { return "The prefix length must be between 0 and \(max)." }
        }
        return nil
    }

    // MARK: Cloud CDN texts (spec 03 §10)

    static func formatMegabytes(_ mb: Double) -> String {
        if mb >= 1024 * 1024 { return String(format: "%.1f TB", locale: .current, mb / (1024 * 1024)) }
        if mb >= 1024 { return String(format: "%.2f GB", locale: .current, mb / 1024) }
        return String(format: "%.1f MB", locale: .current, mb)
    }

    static func trafficText(incoming: Double?, outgoing: Double?, present: Bool) -> String {
        present ? "in \(formatMegabytes(incoming ?? 0)) · out \(formatMegabytes(outgoing ?? 0))" : "–"
    }

    static func displayName(domain: String?, id: String) -> String {
        domain?.nonBlank ?? "Domain …" + String(id.suffix(4))
    }

    /// Android `enableCdn64`: error text of the first failed name, else `nil`.
    static func firstEnableError(_ results: [(name: String?, failed: Bool, error: String?, code: String?)]) -> String? {
        results.first(where: \.failed).map { [$0.name, $0.error ?? $0.code].compactMap { $0 }.joined(separator: ": ") }
    }
}

private nonisolated extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
