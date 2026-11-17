import Foundation
import Darwin

/// A parsed IP address (from a literal or from `getaddrinfo`).
nonisolated enum IPAddressBytes: Equatable, Sendable {
    case v4([UInt8])
    case v6([UInt8])
}

/// Android LocalNodeSupport.kt (spec 01 §5.1–5.6). Pure functions, never perform DNS.
nonisolated enum LocalNodeURL {
    static let defaultNodePort = 8080
    static let localSuffixes = [".local", ".lan", ".home.arpa", ".internal", ".fritz.box", ".home", ".localdomain"]

    /// Form message for an input that `normalizeLocalNodeUrl` rejects.
    static func invalidInputMessage(_ input: String) -> String {
        if input.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("http://") {
            return String(localized: "Enter a valid address. HTTP works with an IP address (e.g. 192.168.1.10 or a public IP) or a local name.")
        }
        return String(localized: "Enter a valid address, e.g. http://192.168.1.10:8080/api")
    }

    // MARK: 5.2 – 5.5

    /// `^\d{1,3}(\.\d{1,3}){3}$` (matches "999.1.1.1" too, like Android).
    static func isIPv4Literal(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { (1...3).contains($0.count) && $0.allSatisfy(\.isASCIIDigit) }
    }

    /// Host as OkHttp reports it (IPv6 without brackets).
    static func isIpHost(_ host: String) -> Bool { host.contains(":") || isIPv4Literal(host) }

    /// Loopback, link-local, IPv4 private ranges, IPv6 ULA (fc00::/7). IPv4-mapped IPv6 is judged as IPv4.
    static func isLocalAddress(_ address: IPAddressBytes) -> Bool {
        switch address {
        case .v4(let b):
            guard b.count == 4 else { return false }
            return b[0] == 127
                || (b[0] == 169 && b[1] == 254)
                || b[0] == 10
                || (b[0] == 172 && (16...31).contains(b[1]))
                || (b[0] == 192 && b[1] == 168)
        case .v6(let b):
            guard b.count == 16 else { return false }
            if b[0..<10].allSatisfy({ $0 == 0 }) && b[10] == 0xFF && b[11] == 0xFF {
                return isLocalAddress(.v4(Array(b[12..<16])))
            }
            let loopback = b[0..<15].allSatisfy { $0 == 0 } && b[15] == 1
            let linkLocal = b[0] == 0xFE && (b[1] & 0xC0) == 0x80
            return loopback || linkLocal || (b[0] & 0xFE) == 0xFC
        }
    }

    /// Parses an IP literal with `inet_pton` (no DNS). Invalid octets (> 255) → nil.
    static func parseLiteral(_ host: String) -> IPAddressBytes? {
        var v4 = in_addr()
        if inet_pton(AF_INET, host, &v4) == 1 {
            return .v4(withUnsafeBytes(of: &v4) { Array($0) })
        }
        var v6 = in6_addr()
        if inet_pton(AF_INET6, host, &v6) == 1 {
            return .v6(withUnsafeBytes(of: &v6) { Array($0) })
        }
        return nil
    }

    static func isLocalHost(_ host: String) -> Bool {
        var h = host.lowercased()
        if h.hasPrefix("[") { h.removeFirst() }
        if h.hasSuffix("]") { h.removeLast() }
        if h.contains(":") || isIPv4Literal(h) {
            guard let address = parseLiteral(h) else { return false }
            return isLocalAddress(address)
        }
        if h.allSatisfy({ $0.isASCIIDigit || $0 == "." }) { return false }
        var name = Substring(h)
        while name.hasSuffix(".") { name.removeLast() }
        return !name.contains(".") || localSuffixes.contains { name.hasSuffix($0) }
    }

    /// Drives the red "unencrypted over the internet" warning.
    static func isPublicHttp(_ url: String) -> Bool {
        guard let parsed = ParsedURL(url) else { return false }
        return parsed.scheme == "http" && !isLocalHost(parsed.host)
    }

    /// Host of a stored node URL (direct node row subtitle).
    static func host(of url: String) -> String? { ParsedURL(url)?.displayHost }

    // MARK: 5.6

    /// Android `normalizeLocalNodeUrl`: e.g. "192.168.1.10" → "http://192.168.1.10:8080/api",
    /// "node.example.com" → "https://node.example.com/api". `nil` = invalid.
    static func normalizeLocalNodeUrl(_ input: String) -> String? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return nil }
        let hasScheme = raw.contains("://")
        guard var url = ParsedURL(hasScheme ? raw : "http://" + raw) else { return nil }
        let local = isLocalHost(url.host)
        let ip = isIpHost(url.host)
        if !hasScheme {
            let beforePath = raw.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            let afterBracket = beforePath.split(separator: "]", omittingEmptySubsequences: false).last ?? ""
            let explicitPort = afterBracket.contains(":")
            if local || ip {
                if !explicitPort { url.port = defaultNodePort }
            } else {
                url.scheme = "https"
            }
        }
        let numeric = url.host.allSatisfy { $0.isASCIIDigit || $0 == "." }
        if url.scheme == "http" && numeric && !isIpHost(url.host) { return nil }
        var path = Substring(url.path)
        while path.hasSuffix("/") { path.removeLast() }
        url.path = path.isEmpty ? "/api" : String(path)
        return url.string
    }
}

/// Minimal URL parser with OkHttp `toHttpUrlOrNull` semantics (scheme http/https, userinfo dropped,
/// lowercase host, canonical IPv6, default port dropped, query/fragment dropped).
nonisolated struct ParsedURL: Equatable, Sendable {
    var scheme: String
    /// Lowercase; IPv6 without brackets, canonical (`fd00::1`).
    var host: String
    /// `nil` = default port of the scheme.
    var port: Int?
    /// Encoded path, starts with "/" or is empty.
    var path: String

    init?(_ string: String) {
        guard let schemeEnd = string.range(of: "://") else { return nil }
        let scheme = string[..<schemeEnd.lowerBound].lowercased()
        guard scheme == "http" || scheme == "https" else { return nil }
        var rest = Substring(string[schemeEnd.upperBound...])
        if let cut = rest.firstIndex(where: { $0 == "?" || $0 == "#" }) { rest = rest[..<cut] }
        let authorityEnd = rest.firstIndex(of: "/") ?? rest.endIndex
        var authority = rest[..<authorityEnd]
        let rawPath = String(rest[authorityEnd...])
        if let at = authority.lastIndex(of: "@") { authority = authority[authority.index(after: at)...] }

        var host: String
        var portText: Substring?
        if authority.hasPrefix("[") {
            guard let close = authority.firstIndex(of: "]") else { return nil }
            let literal = String(authority[authority.index(after: authority.startIndex)..<close])
            guard let canonical = Self.canonicalIPv6(literal) else { return nil }
            host = canonical
            let after = authority[authority.index(after: close)...]
            if !after.isEmpty {
                guard after.hasPrefix(":") else { return nil }
                portText = after.dropFirst()
            }
        } else {
            if let colon = authority.lastIndex(of: ":") {
                portText = authority[authority.index(after: colon)...]
                authority = authority[..<colon]
            }
            host = authority.lowercased()
            // shortcut: non-ASCII (IDN) hosts are rejected instead of punycoded; upgrade if users need IDN node names.
            let invalid = Set(" #%/:?@[\\]^|<>\"{}`")
            guard !host.isEmpty, host.unicodeScalars.allSatisfy({ $0.isASCII && $0.value > 0x20 && $0.value < 0x7F }),
                  !host.contains(where: invalid.contains) else { return nil }
        }
        let defaultPort = scheme == "https" ? 443 : 80
        var port: Int?
        if let portText {
            guard let value = Int(portText), portText.allSatisfy(\.isASCIIDigit), (1...65535).contains(value) else { return nil }
            port = value == defaultPort ? nil : value
        }
        var path = rawPath
        if !path.contains("%") {
            path = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        }
        self.scheme = scheme
        self.host = host
        self.port = port
        self.path = path
    }

    var displayHost: String { host.contains(":") ? "[\(host)]" : host }

    var string: String {
        let defaultPort = scheme == "https" ? 443 : 80
        let portPart = port.map { $0 == defaultPort ? "" : ":\($0)" } ?? ""
        return "\(scheme)://\(displayHost)\(portPart)\(path)"
    }

    private static func canonicalIPv6(_ literal: String) -> String? {
        var address = in6_addr()
        guard inet_pton(AF_INET6, literal, &address) == 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        guard inet_ntop(AF_INET6, &address, &buffer, socklen_t(buffer.count)) != nil else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

private extension Character {
    nonisolated var isASCIIDigit: Bool { isASCII && isNumber }
}
