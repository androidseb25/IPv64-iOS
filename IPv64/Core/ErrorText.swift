import SwiftUI
import IPv64

/// Android `RequestTyp` (models/Enum.kt, spec 01 §6.1): canned error dialogs.
nonisolated enum RequestTyp: CaseIterable, Sendable {
    case tooManyRequests, updateCoolDown, domainNotAvailable, unAuthorized
    case domainLimitReached, domainRulesNotCreated, websiteRequestFailed

    var systemImage: String {
        switch self {
        case .tooManyRequests: "arrow.triangle.2.circlepath.icloud"
        case .updateCoolDown, .websiteRequestFailed: "bolt.fill"
        case .domainNotAvailable, .domainLimitReached, .domainRulesNotCreated: "icloud.slash"
        case .unAuthorized: "exclamationmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .tooManyRequests, .updateCoolDown: .ipv64Orange
        default: .ipv64Red
        }
    }

    var navigationTitle: String {
        switch self {
        case .tooManyRequests, .updateCoolDown: String(localized: "Information")
        case .domainNotAvailable: String(localized: "Error")
        default: String(localized: "Failed")
        }
    }

    var errorTitle: String {
        switch self {
        case .tooManyRequests: String(localized: "Too many requests!")
        case .updateCoolDown: String(localized: "Too many updates!")
        case .domainNotAvailable: String(localized: "Domain not available!")
        case .unAuthorized: String(localized: "Authorization failed!")
        case .domainLimitReached: String(localized: "Domain limit reached!")
        case .domainRulesNotCreated: String(localized: "Domain could not be created!")
        case .websiteRequestFailed: String(localized: "Connection to server failed!")
        }
    }

    var errorDescription: String {
        switch self {
        case .tooManyRequests: String(localized: "You have exceeded your limit of 5 API requests within the allowed 5 seconds.")
        case .updateCoolDown: String(localized: "The A record update can only be run every 5 seconds!")
        case .domainNotAvailable: String(localized: "Your selected domain is already taken!")
        case .unAuthorized: String(localized: "Your authorization on the server has failed, please log in again.")
        case .domainLimitReached: String(localized: "You have reached your domain limit!")
        case .domainRulesNotCreated: String(localized: "Your domain could not be created because it violates the domain rule.")
        case .websiteRequestFailed: String(localized: "A connection to the server could not be established!")
        }
    }

    var status: Int {
        switch self {
        case .tooManyRequests, .updateCoolDown: 429
        case .domainNotAvailable, .domainLimitReached, .domainRulesNotCreated: 403
        case .unAuthorized: 401
        case .websiteRequestFailed: 500
        }
    }
}

/// Android `toError(context)` context.
nonisolated enum ErrorContext: Sendable { case create, update, other }

/// Title + message of an error dialog. Cloud errors: `ErrorText(error)` (Android `toError`),
/// node errors: `ErrorText.node(error)` (Android `localNodeError`). Show with `.errorAlert($error, retry:)`.
nonisolated struct ErrorText: Identifiable, Equatable, Sendable {
    let id = UUID()
    var title: String
    var message: String
    var requestType: RequestTyp?

    init(title: String, message: String, requestType: RequestTyp? = nil) {
        self.title = title
        self.message = message
        self.requestType = requestType
    }

    init(_ type: RequestTyp) {
        self.init(title: type.errorTitle, message: type.errorDescription, requestType: type)
    }

    static func == (lhs: ErrorText, rhs: ErrorText) -> Bool { lhs.id == rhs.id }

    /// Android `IPv64Error.inlineText()` for inline (non-dialog) errors.
    var inlineText: String {
        if requestType != nil {
            return [title, message].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return message.isEmpty ? title : message
    }

    /// Android `IPv64Exception.toError(context)` (spec 01 §7.2).
    init(_ error: any Error, context: ErrorContext = .other) {
        guard let error = error as? IPv64Error else {
            self.init(.websiteRequestFailed)
            return
        }
        switch error {
        case .api(let p):
            self = Self.apiError(status: p.status, code: p.code, detail: p.detail, title: p.title,
                                 field: p.field, retryAfter: p.retryAfter, message: nil, context: context)
        case .httpStatus(let code, _):
            self = Self.apiError(status: code, code: "", detail: "", title: "", field: nil, retryAfter: nil,
                                 message: "HTTP \(code)", context: context)
        case .decoding(let underlying, _):
            self.init(title: String(localized: "Unexpected server response"),
                      message: String(localized: "The app could not read the server response. ")
                        + String(String(describing: underlying).prefix(300)))
        case .missingAPIKey:
            self.init(.unAuthorized)
        default:
            self.init(.websiteRequestFailed)
        }
    }

    private static func apiError(status: Int, code: String, detail: String, title: String, field: String?,
                                 retryAfter: Int?, message: String?, context: ErrorContext) -> ErrorText {
        let info = (code + " " + detail).lowercased()
        if status == 401 { return ErrorText(.unAuthorized) }
        if status == 429 || retryAfter != nil {
            return ErrorText(context == .update ? .updateCoolDown : .tooManyRequests)
        }
        if context == .create && (status == 403 || status == 409) {
            if info.contains("limit") { return ErrorText(.domainLimitReached) }
            if status == 409 || ["not available", "taken", "exists"].contains(where: info.contains) {
                return ErrorText(.domainNotAvailable)
            }
            return ErrorText(.domainRulesNotCreated)
        }
        let detail = detail.nonBlank ?? title.nonBlank
        if status >= 500 {
            let text = (detail ?? String(localized: "The server could not process the request."))
                + " (HTTP \(status)" + (code.isEmpty ? "" : ", \(code)") + ")"
            return ErrorText(title: String(localized: "Server error"), message: text)
        }
        var text = detail ?? message ?? ""
        if let field { text += " (field: \(field))" }
        return ErrorText(title: String(localized: "Loading error"), message: text)
    }

    /// Android `localNodeError(e)` (spec 01 §5.10).
    static func node(_ error: any Error) -> ErrorText {
        if let error = error as? Node64Error {
            switch error {
            case .httpStatus(401, let body) where String(decoding: body, as: UTF8.self).contains("/.node64/login"):
                return ErrorText(
                    title: String(localized: "Address is sign-in protected"),
                    message: String(localized: "PROXY64 asks for a sign-in on this address, so the API key never reaches the node. Use the node's local IP, or give the path /api its own open access list in the PROXY64 host (the node's API key still protects it)."))
            case .api(let e):
                return nodeStatusError(status: e.status, nodeError: e.error)
            case .httpStatus(let code, _):
                return nodeStatusError(status: code, nodeError: nil)
            case .decoding:
                return ErrorText(
                    title: String(localized: "Unexpected response"),
                    message: String(localized: "The address answered, but not like a Node64 API. Check the URL (it usually ends in /api)."))
            default:
                break
            }
        }
        if error is NodeTransportError {
            return ErrorText(
                title: String(localized: "Not a local address"),
                message: String(localized: "Over http:// a name must resolve to an address in your local network. Use the node's IP address or its https:// address."))
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .appTransportSecurityRequiresSecureConnection:
                return ErrorText(
                    title: String(localized: "Unencrypted connection blocked"),
                    message: String(localized: "HTTP is only allowed for IP addresses and local names (e.g. nas.local). Use https:// for a domain."))
            case .serverCertificateUntrusted, .secureConnectionFailed, .serverCertificateHasBadDate,
                 .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected:
                return ErrorText(
                    title: String(localized: "Certificate not trusted"),
                    message: String(localized: "The node's HTTPS certificate is not trusted by this device. Use the node's local http:// address or a valid certificate."))
            default:
                break
            }
        }
        return ErrorText(
            title: String(localized: "Node not reachable"),
            message: String(localized: "Could not reach the node. Is your phone on the same network as the node?"))
    }

    private static func nodeStatusError(status: Int, nodeError: String?) -> ErrorText {
        switch status {
        case 401, 403:
            var lines = [String(localized: "The node rejected the API key (HTTP \(status)).")]
            if let nodeError { lines.append(String(localized: "Node: \(nodeError)")) }
            lines.append(String(localized: "Create a key in the node's web interface on the API tab."))
            return ErrorText(title: String(localized: "API key rejected"), message: lines.joined(separator: "\n"))
        case 404:
            return ErrorText(title: String(localized: "Not a Node64 API"),
                             message: String(localized: "Not a Node64 API — does the URL end in /api?"))
        default:
            return ErrorText(title: String(localized: "Node error"),
                             message: nodeError ?? String(localized: "The node answered with HTTP \(status)."))
        }
    }

    /// Android `"<title>: <text>"` inline form used by node screens.
    var titledText: String { "\(title): \(message)" }
}

// MARK: - Android IPv64Exception predicates (GAP: not in IPv64-SPM)

nonisolated extension IPv64Error {
    var isUnauthorized: Bool { statusCode == 401 || { if case .missingAPIKey = self { true } else { false } }() }
    var isRateLimited: Bool { statusCode == 429 }
    var isForbidden: Bool { statusCode == 403 }
    var isConflict: Bool { statusCode == 409 }
    var isNotFound: Bool { statusCode == 404 }
    var retryAfterSeconds: Int? { if case .api(let p) = self { p.retryAfter } else { nil } }

    /// Android `isPlanRestricted`.
    var isPlanRestricted: Bool {
        guard case .api(let p) = self, p.status == 403 else { return false }
        let info = (p.code + " " + p.detail + " " + p.title).lowercased()
        return ["limit", "plan", "package", "paket", "tarif", "upgrade", "feature", "not available", "not included"]
            .contains(where: info.contains)
    }

    /// Android `isLimitReached`.
    var isLimitReached: Bool { (statusCode == 403 || statusCode == 409) && code == "limit_reached" }

    /// Android `planRestrictionText`.
    var planRestrictionText: String {
        if case .api(let p) = self, let detail = p.detail.nonBlank { return detail }
        return String(localized: "This feature is not available on your plan.")
    }
}

nonisolated extension String {
    /// `nil` when empty or whitespace only (Kotlin `takeIf { it.isNotBlank() }`).
    var nonBlank: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}

// MARK: - Alert

extension View {
    /// Android `ErrorDialog`/`RequestDialogs`: "OK", or "Cancel" + "Retry" when `retry` is given.
    func errorAlert(_ error: Binding<ErrorText?>, retry: (() -> Void)? = nil) -> some View {
        alert(
            Text(verbatim: error.wrappedValue?.title ?? ""),
            isPresented: Binding(get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } }),
            presenting: error.wrappedValue
        ) { _ in
            if let retry {
                Button("Cancel", role: .cancel) {}
                Button("Retry") { retry() }
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { text in
            Text(verbatim: text.message)
        }
    }
}
