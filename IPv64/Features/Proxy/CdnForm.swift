import Foundation
import IPv64

/// Form state of the cloud CDN settings; number fields are text so empty input is possible.
struct CdnForm: Equatable {
    var frontend: CDNFrontend
    var scheme: CDNBackendScheme
    var port: String
    var websocket: Bool
    var cacheEnabled: Bool
    var cacheMinutes: String
    var cacheSizeMB: String
    var aclEnabled: Bool
    var aclMode: CDNAccessListMode

    struct Errors: Equatable {
        var port: String?
        var time: String?
        var size: String?
        var hasAny: Bool { port != nil || time != nil || size != nil }
    }

    struct Request {
        var frontend: CDNFrontend?
        var scheme: CDNBackendScheme?
        var port: Int?
        var websocket: Bool?
        var caching: CDNCachingSettings?
        var accessList: CDNAccessListSettings?
    }

    init(_ d: CDNDomainDetail) {
        frontend = d.proxy?.frontend ?? .http
        scheme = d.proxy?.backend?.scheme ?? .http
        port = d.proxy?.backend?.port.map(String.init) ?? ""
        websocket = d.proxy?.websocket ?? false
        cacheEnabled = d.proxy?.caching?.enabled ?? false
        cacheMinutes = d.proxy?.caching?.timeMinutes.map(String.init) ?? ""
        cacheSizeMB = d.proxy?.caching?.sizeMB.map(String.init) ?? ""
        aclEnabled = d.proxy?.accessList?.enabled ?? false
        aclMode = d.proxy?.accessList?.mode ?? .allowlist
    }

    /// Validation plus PATCH body with only the changed fields (`request == nil`: nothing changed).
    func diff(from start: CdnForm) -> (errors: Errors, request: Request?) {
        var errors = Errors()
        // An empty port stays unchanged as long as nothing is entered.
        let newPort = ProxyLogic.parsePort(port)
        if newPort == nil && (!port.trimmingCharacters(in: .whitespaces).isEmpty || !start.port.isEmpty) {
            errors.port = String(localized: "Enter a port between 1 and 65535.")
        }
        var minutes: Int?, size: Int?
        if cacheEnabled {
            minutes = ProxyLogic.parsePort(cacheMinutes, range: 1...600)
            if minutes == nil { errors.time = String(localized: "Enter 1 to 600 minutes.") }
            else {
                size = Int(cacheSizeMB.trimmingCharacters(in: .whitespaces)).flatMap { $0 >= 1 ? $0 : nil }
                if size == nil { errors.size = String(localized: "Enter a size of at least 1 MB.") }
            }
        }
        if errors.hasAny { return (errors, nil) }

        var caching: CDNCachingSettings?
        if cacheEnabled {
            let c = CDNCachingSettings(
                enabled: start.cacheEnabled ? nil : true,
                timeMinutes: minutes != Int(start.cacheMinutes) || !start.cacheEnabled ? minutes : nil,
                sizeMB: size != Int(start.cacheSizeMB) || !start.cacheEnabled ? size : nil)
            caching = c
        } else if start.cacheEnabled {
            caching = CDNCachingSettings(enabled: false)
        }
        let acl = CDNAccessListSettings(enabled: aclEnabled != start.aclEnabled ? aclEnabled : nil,
                                        mode: aclMode != start.aclMode ? aclMode : nil)
        let aclChanged = acl.enabled != nil || acl.mode != nil
        let request = Request(
            frontend: frontend != start.frontend ? frontend : nil,
            scheme: scheme != start.scheme ? scheme : nil,
            port: newPort != nil && newPort != Int(start.port) ? newPort : nil,
            websocket: websocket != start.websocket ? websocket : nil,
            caching: caching, accessList: aclChanged ? acl : nil)
        let changed = request.frontend != nil || request.scheme != nil || request.port != nil
            || request.websocket != nil || request.caching != nil || request.accessList != nil
        return (errors, changed ? request : nil)
    }
}
