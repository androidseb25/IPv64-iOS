import Foundation
import Synchronization

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(description: message) }
}

/// URLSession's protocol requests are immutable; all test-owned shared state is locked.
private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    private struct State {
        var lastRequest: URLRequest?
        var lastBody: Data?
        var active = 0
        var maximumActive = 0
    }
    private static let state = Mutex(State())
    private let completed = Mutex(false)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    static var lastRequest: URLRequest? { state.withLock { $0.lastRequest } }
    static var lastBody: Data? { state.withLock { $0.lastBody } }
    static var maximumActive: Int { state.withLock { $0.maximumActive } }
    static func resetConcurrency() { state.withLock { $0.maximumActive = $0.active } }

    override func startLoading() {
        let body: Data?
        if let data = request.httpBody {
            body = data
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(buffer, count: count)
            }
            body = data
        } else {
            body = nil
        }
        Self.state.withLock {
            $0.lastRequest = request
            $0.lastBody = body
            $0.active += 1
            $0.maximumActive = max($0.maximumActive, $0.active)
        }
        let delay: TimeInterval = request.url!.path == "/delay" ? 0.150 : 0
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
            guard finishOnce() else { return }
            deliverResponse()
        }
    }

    override func stopLoading() { _ = finishOnce() }

    private func finishOnce() -> Bool {
        let first = completed.withLock { done in
            if done { return false }
            done = true
            return true
        }
        if first { Self.state.withLock { $0.active -= 1 } }
        return first
    }

    private func deliverResponse() {
        let url = request.url!
        if url.path == "/offline" || url.path == "/timeout" {
            client?.urlProtocol(self, didFailWithError: URLError(url.path == "/offline" ? .notConnectedToInternet : .timedOut))
            return
        }
        let code: Int
        switch url.path {
        case "/unauthorized": code = 401
        case "/forbidden": code = 403
        case "/rate-limit": code = 429
        case "/server-error": code = 500
        default: code = 200
        }
        let response: URLResponse = url.path == "/invalid-response"
            ? URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            : HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let logicalStatus = url.path == "/logical-unauthorized" ? "401" : url.path == "/logical-rate-limit" ? "429" : "200"
        client?.urlProtocol(self, didLoad: Data("{\"status\":\"\(logicalStatus)\"}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

@main
private struct CoreRegressionTests {
    static func main() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        try testCodable()
        try await testRequest(session)
        try await testErrors(session)
        try await testCancellation(session)
        try await benchmarkConcurrentRequests(session)
        print("PASS: all core regression checks; no external network or account access")
    }

    private static func url(_ path: String) -> URL { URL(string: "https://tests.invalid\(path)")! }

    private static func testRequest(_ session: URLSession) async throws {
        let fields = ["name": "a+b &= %/?#", "unicode": "Grüße"]
        let expected = "name=a%2Bb%20%26%3D%20%25%2F%3F%23&unicode=Gr%C3%BC%C3%9Fe"
        try require(String(data: APITransport.formBody(fields), encoding: .utf8) == expected, "Form escaping changed reserved characters")
        let response = try await APITransport.data(url: url("/success"), token: "test-token", method: "POST", fields: fields, session: session)
        try require(String(data: response, encoding: .utf8) == "{\"status\":\"200\"}", "Successful response changed")
        try require(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test-token", "Authorization header is invalid")
        try require(MockURLProtocol.lastRequest?.httpMethod == "POST", "HTTP method changed")
        try require(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded; charset=utf-8", "Form content type is invalid")
        try require(MockURLProtocol.lastBody == Data(expected.utf8), "URLSession request body differs from encoded form")
        _ = try await APITransport.data(url: url("/success"), session: session)
        try require(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == nil, "Anonymous request inherited credentials")
        print("PASS: form escaping, request body, authorization, anonymous request")
    }

    private static func testErrors(_ session: URLSession) async throws {
        let cases: [(String, (Error) -> Bool)] = [
            ("/unauthorized", { if case APIError.unauthorized = $0 { return true }; return false }),
            ("/forbidden", { if case APIError.unauthorized = $0 { return true }; return false }),
            ("/rate-limit", { if case APIError.rateLimited = $0 { return true }; return false }),
            ("/server-error", { if case APIError.http(500) = $0 { return true }; return false }),
            ("/logical-unauthorized", { if case APIError.unauthorized = $0 { return true }; return false }),
            ("/logical-rate-limit", { if case APIError.rateLimited = $0 { return true }; return false }),
            ("/invalid-response", { if case APIError.invalidResponse = $0 { return true }; return false }),
            ("/offline", { ($0 as? URLError)?.code == .notConnectedToInternet }),
            ("/timeout", { ($0 as? URLError)?.code == .timedOut })
        ]
        for (path, matches) in cases {
            do {
                _ = try await APITransport.data(url: url(path), token: "test-token", session: session)
                throw TestFailure(description: "Expected failure for \(path)")
            } catch {
                try require(matches(error), "Wrong error for \(path): \(error)")
            }
        }
        do {
            _ = try await APITransport.data(url: url("/success"), token: "", session: session)
            throw TestFailure(description: "Empty API key accepted")
        } catch APIError.unauthorized { }
        try require(APITransport.message(for: URLError(.timedOut)).contains("timed out"), "Timeout guidance missing")
        try require(APITransport.message(for: URLError(.notConnectedToInternet)).contains("Connection unavailable"), "Offline guidance missing")
        print("PASS: HTTP 401/403/429/500, API-level errors, invalid response, offline, timeout, empty key")
    }

    private static func testCancellation(_ session: URLSession) async throws {
        let task = Task { try await APITransport.data(url: url("/delay"), session: session) }
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()
        do {
            _ = try await task.value
            throw TestFailure(description: "Cancelled request completed successfully")
        } catch {
            try require(APITransport.isCancellation(error), "Cancellation misclassified: \(error)")
        }
        print("PASS: request cancellation")
    }

    private static func testCodable() throws {
        try require(APITransport.isSuccessStatus("200"), "Numeric success status rejected")
        try require(APITransport.isSuccessStatus("200 OK"), "HTTP-style success status rejected")
        try require(APITransport.isSuccessStatus("success"), "Text success status rejected")
        try require(!APITransport.isSuccessStatus("401 Unauthorized"), "Unauthorized status accepted")
        try require(APITransport.statusCode("401 Unauthorized") == 401, "HTTP-style error status not parsed")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let event = HealthEvents(event_time: nil, status: 4, text: "Alarm")
        let restoredEvent = try decoder.decode(HealthEvents.self, from: encoder.encode(event))
        // UUID is a transient UI identity; compare persisted event fields.
        try require(restoredEvent.event_time == nil && restoredEvent.status == 4 && restoredEvent.text == "Alarm", "HealthEvents roundtrip failed")
        var check = HealthCheck(name: "API", healthstatus: 4, healthtoken: "test-check", add_time: nil,
                                last_update_time: nil, alarm_time: nil, events: [event])
        check.keyInd = "original-key"
        let restored = try decoder.decode(HealthCheck.self, from: encoder.encode(check))
        try require(restored.add_time == nil && restored.last_update_time == nil && restored.alarm_time == nil, "Optional dates were lost")
        try require(restored.healthtoken == check.healthtoken && restored.keyInd == "original-key", "Root object identity roundtrip failed")
        let restoredArray = try decoder.decode([HealthCheck].self, from: encoder.encode([check]))
        try require(restoredArray.first?.keyInd == "original-key" && restoredArray.first?.events.first?.status == 4, "Cache array roundtrip failed")
        var apiCheck = try JSONSerialization.jsonObject(with: encoder.encode(check)) as! [String: Any]
        apiCheck.removeValue(forKey: "keyInd")
        apiCheck["add_time"] = NSNull()
        let payload: [String: Any] = ["api-check-key": apiCheck, "info": "ok", "status": "200", "get_account_info": ""]
        let apiResult = try decoder.decode(HealthCheckResult.self, from: JSONSerialization.data(withJSONObject: payload))
        try require(apiResult.domain.count == 1 && apiResult.domain[0].keyInd == "api-check-key", "Dynamic API key decoding failed")
        try require(apiResult.domain[0].add_time == nil && apiResult.status == "200", "API null date or status decoding failed")
        print("PASS: event/check Codable, optional dates, root/cache identity, dynamic API decoding")
    }

    private static func benchmarkConcurrentRequests(_ session: URLSession) async throws {
        MockURLProtocol.resetConcurrency()
        let serialStart = ContinuousClock.now
        for _ in 0..<3 { _ = try await APITransport.data(url: url("/delay"), session: session) }
        let serial = serialStart.duration(to: .now)
        try require(MockURLProtocol.maximumActive == 1, "Serial benchmark unexpectedly overlapped")
        MockURLProtocol.resetConcurrency()
        let parallelStart = ContinuousClock.now
        async let first = APITransport.data(url: url("/delay"), session: session)
        async let second = APITransport.data(url: url("/delay"), session: session)
        async let third = APITransport.data(url: url("/delay"), session: session)
        _ = try await (first, second, third)
        let parallel = parallelStart.duration(to: .now)
        try require(MockURLProtocol.maximumActive == 3, "Independent requests did not overlap")
        print("MOCK BENCHMARK (three 150 ms responses, not production): serial=\(serial), parallel=\(parallel)")
    }
}
