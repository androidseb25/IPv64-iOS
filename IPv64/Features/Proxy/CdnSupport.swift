import SwiftUI
import IPv64

// Cloud CDN helpers and labels (Android CdnSupport.kt). Open enums are compared by `rawValue`.

extension CDNDomain {
    var isBusy: Bool { cdnIsBusy(pending: pending, proxy: proxy?.state, portmapper: portmapper?.state) }
    var displayName: String { ProxyLogic.displayName(domain: domain, id: id) }
    var trafficText: String {
        ProxyLogic.trafficText(incoming: trafficMB?.incoming, outgoing: trafficMB?.outgoing, present: trafficMB != nil)
    }
}

extension CDNDomainDetail {
    var isBusy: Bool { cdnIsBusy(pending: pending, proxy: proxy?.state, portmapper: portmapper?.state) }
    var displayName: String { ProxyLogic.displayName(domain: domain, id: id) }
    var trafficText: String {
        ProxyLogic.trafficText(incoming: trafficMB?.incoming, outgoing: trafficMB?.outgoing, present: trafficMB != nil)
    }
}

/// Work of the CDN bot is open or something is being switched off → polling needed.
func cdnIsBusy(pending: [CDNPendingTask]?, proxy: CDNProxyState?, portmapper: CDNPortmapperState?) -> Bool {
    !(pending ?? []).isEmpty || proxy == .disabling || portmapper == .disabling
}

extension CDNPendingTask {
    var label: String {
        switch self {
        case .serverAssignment: String(localized: "Assigning CDN server")
        case .dns: String(localized: "Updating DNS")
        case .configDeploy: String(localized: "Deploying configuration")
        case .certificate: String(localized: "Issuing certificate")
        case .serverMove: String(localized: "Moving to another server")
        case .deletion: String(localized: "Removing from CDN")
        default: rawValue
        }
    }
}

extension Optional where Wrapped == CDNProxyState {
    var label: String {
        switch self {
        case .some(.on): String(localized: "Proxy on")
        case .some(.off): String(localized: "Proxy off")
        case .some(.disabling): String(localized: "Proxy switching off")
        default: String(localized: "Proxy unknown")
        }
    }

    var color: Color {
        switch self {
        case .some(.on): .ipv64Green
        case .some(.disabling): .ipv64Orange
        default: .ipv64Gray
        }
    }
}

extension Optional where Wrapped == CDNPortmapperState {
    var label: String {
        switch self {
        case .some(.on): String(localized: "On")
        case .some(.off): String(localized: "Off")
        case .some(.disabling): String(localized: "Switching off")
        case .some(.suspendedTrafficLimit): String(localized: "Suspended (traffic limit reached)")
        default: String(localized: "Unknown")
        }
    }

    var color: Color {
        switch self {
        case .some(.on): .ipv64Green
        case .some(.disabling): .ipv64Orange
        case .some(.suspendedTrafficLimit): .ipv64Red
        default: .ipv64Gray
        }
    }
}

extension CDNFrontend {
    static let all: [CDNFrontend] = [.http, .httpsRedirect, .httpAndHTTPS]

    var label: String {
        switch self {
        case .http: String(localized: "HTTP only")
        case .httpsRedirect: String(localized: "Redirect HTTP to HTTPS")
        case .httpAndHTTPS: String(localized: "HTTP and HTTPS")
        default: String(localized: "Unknown")
        }
    }

    var hint: String {
        switch self {
        case .http: String(localized: "Visitors connect without encryption.")
        case .httpsRedirect: String(localized: "HTTP requests are redirected to HTTPS. A Let's Encrypt certificate is issued.")
        default: String(localized: "Both HTTP and HTTPS are served. A Let's Encrypt certificate is issued.")
        }
    }
}

extension CDNBackendScheme {
    static let all: [CDNBackendScheme] = [.http, .https]
    var label: String {
        switch self {
        case .http: "HTTP"
        case .https: "HTTPS"
        default: String(localized: "Unknown")
        }
    }
}

extension CDNCertificate {
    var label: String {
        switch self {
        case .default: String(localized: "Default certificate")
        case .letsEncrypt: "Let's Encrypt"
        case .issuing: String(localized: "Being issued")
        default: String(localized: "Unknown")
        }
    }
}

extension CDNAccessListMode {
    static let all: [CDNAccessListMode] = [.allowlist, .denylist]
    var label: String {
        switch self {
        case .allowlist: String(localized: "Allowlist (only listed addresses may connect)")
        case .denylist: String(localized: "Denylist (listed addresses are blocked)")
        default: String(localized: "Unknown")
        }
    }
}

extension CDNTransport {
    static let all: [CDNTransport] = [.tcp, .udp]
    var label: String { self == .udp ? "UDP" : "TCP" }
}

extension CDNRecordMode {
    static let all: [CDNRecordMode] = [.full, .otherFamilyOnly]

    var title: String {
        self == .full ? String(localized: "Full") : String(localized: "Other address family only")
    }

    var detail: String {
        self == .full
            ? String(localized: "The name points completely to the CDN. All visitors reach your server through the CDN.")
            : String(localized: "The record stays directly reachable and the CDN serves only the other address family, for example IPv4 for an IPv6-only connection. Only possible if this is the only record on its name.")
    }
}

extension Record {
    var cdnStateLabel: String {
        switch state {
        case .active: String(localized: "Direct")
        case .inactive: String(localized: "Inactive")
        case .cdnProxied: String(localized: "Via CDN")
        case .cdnPartial: String(localized: "Partly via CDN")
        case .cdnRecord: String(localized: "Managed by CDN")
        case .failoverRecord: String(localized: "Failover record")
        case .failoverReplaced: String(localized: "Replaced by failover")
        default: String(localized: "Unknown")
        }
    }

    var cdnStateColor: Color {
        switch state {
        case .cdnProxied, .cdnPartial: .ipv64Blue
        case .active: .ipv64Green
        case .failoverRecord, .failoverReplaced: .ipv64Orange
        default: .ipv64Gray
        }
    }

    var canEnableCdn: Bool { state == .active }
    var canDisableCdn: Bool { state == .cdnProxied || state == .cdnPartial }

    var cdnTitle: String {
        let name = fqdn?.nonBlank ?? [prefix ?? "", domain ?? ""].filter { !$0.isEmpty }.joined(separator: ".")
        return "\(name) (\(type?.rawValue ?? "?"))"
    }
}
