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
