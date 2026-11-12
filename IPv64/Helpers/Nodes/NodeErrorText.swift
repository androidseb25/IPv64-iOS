import Foundation
import IPv64

extension ErrorText {
    /// Android `localNodeError(e)`: title + text for errors of direct node access.
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

    /// Android `"<title>: <text>"` inline form used by the node sheets.
    var titledText: String { "\(title): \(message)" }
}
