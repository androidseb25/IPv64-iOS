import Foundation
import IPv64

/// Editable state of the proxy host editor (spec 03 §5.3 fill defaults, §5.5 payload).
struct ProxyHostForm: Equatable {
    var kind: Node64.ProxyHostKind = .proxy
    var names = ""
    var enabled = true
    var scheme: Node64.ProxyHostScheme = .http
    var host = ""
    var port = "80"
    var websockets = false
    var blockExploits = false
    var cacheAssets = false
    var forceSSL = false
    var http2 = false
    var http3 = false
    var hsts = false
    var hstsSubdomains = false
    var verifyTarget = false
    var minTLS: Node64.ProxyHostMinTLS?
    var accessListID = 0
    var certID = 0
    var redirectTarget = ""
    var redirectScheme: Node64.ProxyHostRedirectScheme = .auto
    var redirectCode = 301
    var preservePath = true

    static let redirectCodes = [300, 301, 302, 303, 307, 308]

    init() {}

    init(host h: Node64.ProxyHost) {
        kind = h.kind ?? .proxy
        names = (h.names ?? []).joined(separator: "\n")
        enabled = h.enabled != false
        scheme = h.scheme ?? .http
        host = h.targetHost ?? ""
        port = h.targetPort.map(String.init) ?? ""
        websockets = h.websockets == true
        blockExploits = h.blockExploits == true
        cacheAssets = h.cacheAssets == true
        forceSSL = h.forceSSL == true
        http2 = h.http2 == true
        http3 = h.http3 == true
        hsts = h.hsts == true
        hstsSubdomains = h.hstsSubdomains == true
        verifyTarget = h.verifyTarget == true
        minTLS = h.minTLS
        accessListID = h.accessListID ?? 0
        certID = h.certID ?? 0
        redirectTarget = h.redirectTarget ?? ""
        redirectScheme = h.redirectScheme ?? .auto
        redirectCode = h.redirectCode ?? 301
        preservePath = h.preservePath != false
    }

    var isProxy: Bool { kind == .proxy }
    var isRedirect: Bool { kind == .redirect }
    /// Other kinds (404, passthrough, status) only edit names.
    var editable: Bool { isProxy || isRedirect }
    var firstName: String { names.split(separator: "\n").first.map(String.init) ?? "" }

    var validationError: String? {
        ProxyLogic.hostError(names: ProxyLogic.parseNames(names), isProxy: isProxy, isRedirect: isRedirect,
                             host: host, port: port, redirectTarget: redirectTarget)
    }

    /// `nil` fields are not sent; `enabled`/`kind` only on create.
    func input(create: Bool) -> Node64.ProxyHostInput {
        let nameList = ProxyLogic.parseNames(names)
        guard editable else { return Node64.ProxyHostInput(names: nameList) }
        return Node64.ProxyHostInput(
            kind: create ? kind : nil, names: nameList, enabled: create ? enabled : nil,
            scheme: isProxy ? scheme : nil, targetHost: isProxy ? host.trimmingCharacters(in: .whitespaces) : nil,
            targetPort: isProxy ? ProxyLogic.parsePort(port) : nil,
            websockets: isProxy ? websockets : nil, blockExploits: isProxy ? blockExploits : nil,
            cacheAssets: isProxy ? cacheAssets : nil, certID: certID, forceSSL: forceSSL,
            http2: http2, http3: http3, hsts: hsts, hstsSubdomains: hstsSubdomains, minTLS: minTLS,
            verifyTarget: isProxy ? verifyTarget : nil,
            redirectTarget: isRedirect ? redirectTarget.trimmingCharacters(in: .whitespaces) : nil,
            redirectScheme: isRedirect ? redirectScheme : nil, redirectCode: isRedirect ? redirectCode : nil,
            preservePath: isRedirect ? preservePath : nil, accessListID: accessListID)
    }
}
