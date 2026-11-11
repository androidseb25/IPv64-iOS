import Foundation
import IPv64

/// DynDNS list logic (ported from Android 2.1.0): zones, kind filter and the IP status of a domain.
nonisolated enum DynDNSLogic {
    static let noIPv4 = "0.0.0.0"
    static let noIPv6 = "::"
    static let ownDomain = "Own Domain"

    /// Section order of the list.
    static let zones = [
        "ipv64.net", "ipv64.de", "any64.de", "api64.de", "dns64.de", "dyndns64.de", "eth64.de", "dynipv6.de",
        "home64.de", "iot64.de", "lan64.de", "nas64.de", "root64.de", "route64.de", "srv64.de", "tcp64.de",
        "udp64.de", "vpn64.de", "wan64.de", ownDomain,
    ]

    static let newRecordTypes = ["A", "AAAA", "TXT", "MX", "NS", "SRV", "CNAME", "TLSA", "CAA"]
    static let allRecordTypes = ["A", "AAAA", "CNAME", "MX", "TXT", "NS", "SRV", "TLSA", "CAA"]

    /// A non-blank IP that is not the "no IP" placeholder or loopback, else `nil`.
    static func knownIp(_ ip: String?) -> String? {
        guard let ip = ip?.trimmingCharacters(in: .whitespacesAndNewlines), !ip.isEmpty,
              ip != noIPv4, ip != noIPv6, ip != "::1" else { return nil }
        return ip
    }

    static func baseDomain(_ name: String) -> String {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return ownDomain }
        let base = parts.suffix(2).joined(separator: ".")
        return zones.contains(base) ? base : ownDomain
    }

    static func isOwn(kind: DomainKind?, name: String) -> Bool {
        (kind ?? (baseDomain(name) == ownDomain ? .own : .dyndns)) == .own
    }

    enum IpStatus: Sendable { case checking, noIp, unknown, differs, matches }

    static func hasIp(_ detail: DomainDetail?) -> Bool {
        (detail?.records ?? []).contains { $0.type == .a || $0.type == .aaaa }
    }

    /// An A record exists, none holds the current IPv4, and IPv4 is not ignored for this domain.
    static func mismatchV4(_ detail: DomainDetail?, myV4: String) -> Bool {
        guard let detail, myV4 != noIPv4, detail.ignore != .ipv4 else { return false }
        let records = (detail.records ?? []).filter { $0.type == .a }
        return !records.isEmpty && !records.contains { $0.content == myV4 }
    }

    /// Like `mismatchV4`; a fixed IPv6 prefix means the AAAA records are not the device address.
    static func mismatchV6(_ detail: DomainDetail?, myV6: String) -> Bool {
        guard let detail, myV6 != noIPv6, detail.ignore != .ipv6,
              (detail.ipv6Prefix ?? "").trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        let records = (detail.records ?? []).filter { $0.type == .aaaa }
        return !records.isEmpty && !records.contains { $0.content == myV6 }
    }

    /// `nil` detail = still loading.
    static func status(_ detail: DomainDetail?, myV4: String, myV6: String) -> IpStatus {
        guard let detail else { return .checking }
        if !hasIp(detail) { return .noIp }
        if myV4 == noIPv4 && myV6 == noIPv6 { return .unknown }
        return mismatchV4(detail, myV4: myV4) || mismatchV6(detail, myV6: myV6) ? .differs : .matches
    }

    static func kindLabel(_ kind: DomainKind?) -> String {
        switch kind {
        case .dyndns: "DynDNS"
        case .own: "Own domain"
        default: "–"
        }
    }

    static func ignoreLabel(_ ignore: DomainIgnore?) -> String {
        switch ignore {
        case .ipv4: "Ignore IPv4"
        case .ipv6: "Ignore IPv6"
        default: "None"
        }
    }

    // MARK: Records

    static func isLocked(_ state: RecordState?) -> Bool {
        guard let state else { return false }
        return [.cdnRecord, .cdnProxied, .cdnPartial, .failoverRecord, .failoverReplaced].contains(state)
    }

    static func lockReason(_ state: RecordState?) -> String? {
        switch state {
        case .cdnRecord, .cdnProxied, .cdnPartial: "Managed by the CDN. Change it in the CDN settings."
        case .failoverRecord, .failoverReplaced: "Managed by DNS failover. Change it in the failover policy."
        default: nil
        }
    }

    static func stateLabel(_ state: RecordState?) -> String? {
        switch state {
        case .active: "Active"
        case .inactive: "Inactive"
        case .cdnRecord: "CDN"
        case .cdnProxied: "CDN proxied"
        case .cdnPartial: "CDN partial"
        case .failoverRecord: "Failover"
        case .failoverReplaced: "Replaced by failover"
        default: state?.rawValue
        }
    }

    /// Prefix, "@" when empty (the domain itself).
    static func prefixLabel(_ prefix: String?) -> String {
        guard let prefix, !prefix.trimmingCharacters(in: .whitespaces).isEmpty, prefix != "@" else { return "@" }
        return prefix
    }

    /// Edit form value: "" for the apex.
    static func editPrefix(_ prefix: String?) -> String {
        guard let prefix, prefix != "@" else { return "" }
        return prefix
    }

    private static func typeOrder(_ type: RecordType?) -> Int {
        type.flatMap { allRecordTypes.firstIndex(of: $0.rawValue) } ?? allRecordTypes.count
    }

    /// Sorted by type order then prefix, grouped by type (keeps the sort order).
    static func groupedRecords(_ records: [Record]) -> [(type: String, records: [Record])] {
        let sorted = records.sorted {
            let (a, b) = (typeOrder($0.type), typeOrder($1.type))
            return a != b ? a < b : prefixLabel($0.prefix) < prefixLabel($1.prefix)
        }
        var groups: [(type: String, records: [Record])] = []
        for record in sorted {
            let type = record.type?.rawValue ?? "?"
            if let last = groups.indices.last, groups[last].type == type {
                groups[last].records.append(record)
            } else {
                groups.append((type, [record]))
            }
        }
        return groups
    }

    // MARK: DynDNS result

    static func outcomeLabel(_ outcome: DynDNSOutcome?) -> String {
        switch outcome {
        case .created: "created"
        case .updated: "updated"
        case .unchanged: "unchanged"
        case .ignored: "ignored (domain setting)"
        case .invalidIP: "invalid IP"
        case .cnameConflict: "CNAME conflict"
        case .cdnManaged: "managed by the CDN"
        default: "unknown"
        }
    }

    static func isFailure(_ outcome: DynDNSOutcome?) -> Bool {
        outcome == .invalidIP || outcome == .cnameConflict || outcome == .cdnManaged
    }

    // MARK: Validation

    /// Four decimal parts 0...255 without leading zeros, no trimming.
    static func isIpv4(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { part in
            (1...3).contains(part.count) && part.allSatisfy { $0.isASCII && $0.isNumber }
                && (part.count == 1 || part.first != "0") && Int(part).map { $0 <= 255 } == true
        }
    }

    /// Numeric IPv6 only; IPv4-mapped `::ffff:a.b.c.d` is rejected (Android parses it as an IPv4 address).
    static func isIpv6(_ text: String) -> Bool {
        guard text.contains(":"), text.count <= 45, !text.contains("%") else { return false }
        var bytes = in6_addr()
        guard inet_pton(AF_INET6, text, &bytes) == 1 else { return false }
        let b = withUnsafeBytes(of: bytes) { Array($0) }
        let mapped = b[0..<10].allSatisfy { $0 == 0 } && b[10] == 0xff && b[11] == 0xff
        return !mapped
    }

    /// Empty is fine; else `addr[/len]` with hex digits and colons, len 1...128.
    static func isValidIpv6Prefix(_ text: String) -> Bool {
        guard !text.isEmpty else { return true }
        let addr = text.prefix { $0 != "/" }
        let len = text.contains("/") ? text.drop { $0 != "/" }.dropFirst() : ""
        let addrOk = addr.contains(":") && addr.allSatisfy { $0 == ":" || $0.isHexDigit }
        let lenOk = len.isEmpty || (len.allSatisfy { $0.isASCII && $0.isNumber } && Int(len).map { (1...128).contains($0) } == true)
        return addrOk && lenOk
    }

    /// New domain subdomain: one label, no dots or whitespace.
    static func isValidSubdomain(_ text: String) -> Bool {
        !text.isEmpty && !text.contains(".") && !text.contains { $0.isWhitespace }
    }

    static func updateURL(token: String?) -> String? {
        token.flatMap { $0.isEmpty ? nil : "https://ipv64.net/nic/update?key=\($0)" }
    }
}

nonisolated enum DomainKindFilter: String, CaseIterable, Identifiable, Sendable {
    case all, dyndns, own
    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .dyndns: "DynDNS"
        case .own: "Own"
        }
    }

    func matches(kind: DomainKind?, name: String) -> Bool {
        switch self {
        case .all: true
        case .dyndns: !DynDNSLogic.isOwn(kind: kind, name: name)
        case .own: DynDNSLogic.isOwn(kind: kind, name: name)
        }
    }
}

extension DynDNSLogic {
    /// Android `formatGermanTime`: dd.MM.yyyy HH:mm:ss.
    static func germanTime(_ date: Date?, fallback: String = "–") -> String {
        guard let date else { return fallback }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return formatter.string(from: date)
    }
}
