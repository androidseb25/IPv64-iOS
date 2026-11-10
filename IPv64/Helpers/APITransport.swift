import Foundation
import OSLog

nonisolated enum APITransport {
    static let endpoint = URL(string: "https://ipv64.net/api.php")!
    private static let logger = Logger(subsystem: "de.rpicloud.IPv64", category: "Network")

    /// IPv64 returns either a numeric status (for example `200`) or an HTTP
    /// style status string (for example `200 OK`). Some endpoints also use
    /// `success`. Keep the interpretation in one place so callers do not
    /// reject a valid response because of formatting differences.
    static func isSuccessStatus(_ status: String) -> Bool {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.caseInsensitiveCompare("success") == .orderedSame { return true }
        guard let code = statusCode(status) else { return false }
        return (200..<300).contains(code)
    }

    static func statusCode(_ status: String) -> Int? {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(normalized.split(separator: " ", maxSplits: 1).first ?? "")
    }

    static func formBody(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return fields.sorted { $0.key < $1.key }.map {
            "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&").data(using: .utf8)!
    }

    static func data(url: URL, token: String? = nil, method: String = "GET",
                     fields: [String: String] = [:], session: URLSession = .shared) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            guard !token.isEmpty else { throw APIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if !fields.isEmpty {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = formBody(fields)
        }
        let started = ContinuousClock.now
        defer {
            // Never log URLs, payloads, headers or server responses: they may contain credentials.
            let elapsed = started.duration(to: .now)
            logger.debug("Request completed in \(String(describing: elapsed), privacy: .public)")
        }
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch response.statusCode {
        case 200..<300: break
        case 401, 403: throw APIError.unauthorized
        case 429: throw APIError.rateLimited
        default: throw APIError.http(response.statusCode)
        }
        // The service can also return API failures inside an HTTP 200 response.
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = object["status"] as? String, let code = statusCode(status), code >= 400 {
            if code == 401 || code == 403 { throw APIError.unauthorized }
            if code == 429 { throw APIError.rateLimited }
            throw APIError.http(code)
        }
        return data
    }

    static func message(for error: Error) -> String {
        if let error = error as? APIError { return error.localizedDescription }
        if error is DecodingError { return "The server returned an unexpected response. Please try again later." }
        if let error = error as? URLError {
            switch error.code {
            case .timedOut: return "The request timed out. Please try again."
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                return "Connection unavailable. Previously loaded data remains visible. Please try again."
            default: break
            }
        }
        return "The request could not be completed. Please try again."
    }

    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}

nonisolated enum APIError: LocalizedError {
    case unauthorized, rateLimited, invalidResponse, http(Int)
    var errorDescription: String? {
        switch self {
        case .unauthorized: "The API key is invalid or access is denied. Please check your account."
        case .rateLimited: "The API limit has been reached. Please try again later."
        case .invalidResponse: "The server returned an unexpected response."
        case .http(let code): "The server could not complete the request (HTTP \(code)). Please try again later."
        }
    }
}
