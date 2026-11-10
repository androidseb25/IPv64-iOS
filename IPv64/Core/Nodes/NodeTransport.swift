import Foundation
import Darwin
import IPv64

/// Thrown when an `http://` node name does not resolve to local addresses only (→ "Not a local address").
nonisolated struct NodeTransportError: Error, Sendable {
    let host: String
}

/// Hardened transport for direct node access (Android `localBaseClient`/`localHttpClient`, spec 01 §5.9):
/// no redirects; for `http://` no proxy, and a host name must resolve (getaddrinfo) to local addresses only,
/// then the request goes to that IP literal with the original `Host` header (prevents DNS rebinding).
/// Timeouts: 15 s per request (set by `Node64.Configuration.timeoutInterval`), 5 s idle on the session.
/// shortcut: URLSession has no separate connect timeout; the 5 s idle timeout is the closest equivalent.
nonisolated final class NodeTransport: IPv64Transport {
    private let session: URLSession

    init(plainHTTP: Bool) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        if plainHTTP {
            configuration.connectionProxyDictionary = [kCFNetworkProxiesHTTPEnable as String: false]
        }
        session = URLSession(configuration: configuration, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }

    deinit { session.finishTasksAndInvalidate() }

    @concurrent
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if let url = request.url, url.scheme?.lowercased() == "http",
           let host = url.host(percentEncoded: false), !LocalNodeURL.isIpHost(host) {
            let addresses = try Self.resolve(host)
            guard !addresses.isEmpty, addresses.allSatisfy(LocalNodeURL.isLocalAddress) else {
                throw NodeTransportError(host: host)
            }
            // Like OkHttp: try every resolved address until one accepts the connection.
            var lastError: any Error = NodeTransportError(host: host)
            for address in addresses {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.host = Self.literal(address)
                guard let pinned = components?.url else { continue }
                var pinnedRequest = request
                pinnedRequest.url = pinned
                pinnedRequest.setValue(url.port.map { "\(host):\($0)" } ?? host, forHTTPHeaderField: "Host")
                do {
                    return try await perform(pinnedRequest)
                } catch let error as URLError where error.code == .cannotConnectToHost || error.code == .timedOut {
                    lastError = error
                }
            }
            throw lastError
        }
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw IPv64Error.invalidResponse }
        return (data, http)
    }

    /// Blocking system lookup; only called from the concurrent `send`.
    private static func resolve(_ host: String) throws -> [IPAddressBytes] {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let head = result else { throw URLError(.cannotFindHost) }
        defer { freeaddrinfo(head) }
        var addresses: [IPAddressBytes] = []
        for info in sequence(first: head, next: { $0.pointee.ai_next }) {
            guard let sa = info.pointee.ai_addr else { continue }
            switch Int32(sa.pointee.sa_family) {
            case AF_INET:
                var addr = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                addresses.append(.v4(withUnsafeBytes(of: &addr) { Array($0) }))
            case AF_INET6:
                var addr = sa.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee.sin6_addr }
                addresses.append(.v6(withUnsafeBytes(of: &addr) { Array($0) }))
            default:
                continue
            }
        }
        return addresses
    }

    private static func literal(_ address: IPAddressBytes) -> String {
        switch address {
        case .v4(let b):
            return b.map(String.init).joined(separator: ".")
        case .v6(var b):
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            _ = inet_ntop(AF_INET6, &b, &buffer, socklen_t(buffer.count))
            return "[" + String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self) + "]"
        }
    }
}

/// Refuses every redirect (Android `followRedirects = false`); the 3xx answer is returned as is.
private nonisolated final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    // The async variant of this delegate method crashes the Swift 6.4 compiler (ObjC thunk); keep the handler form.
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Android `localNodeClient(url, key)`: one cheap Node64 client per call, agent actor "IPv64 iOS".
nonisolated enum NodeClientFactory {
    static func client(url: String, key: String) -> Node64? {
        guard let baseURL = URL(string: url) else { return nil }
        let plainHTTP = baseURL.scheme?.lowercased() == "http"
        return Node64(
            configuration: .init(baseURL: baseURL, apiKey: key, agentActor: AppConfig.nodeAgentActor, timeoutInterval: 15),
            transport: NodeTransport(plainHTTP: plainHTTP))
    }

    static func client(for access: LocalNodeStore.Access) -> Node64? { client(url: access.url, key: access.key) }
}
