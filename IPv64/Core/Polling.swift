import Foundation
import IPv64

/// Android `ipv64Retrying`: on a 429 with `retryAfter <= 5` (default 3) wait and run ONCE more.
/// Other errors and cancellation propagate.
func ipv64Retrying<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch let error as IPv64Error {
        let wait = error.retryAfterSeconds ?? 3
        guard error.isRateLimited, wait <= 5 else { throw error }
        try await Task.sleep(for: .seconds(max(wait, 1)))
        return try await operation()
    }
}

/// Android `pollUntil(intervalMs, maxMs, onEach, fetch, done)` (spec 01 §7.1).
/// Sleeps BEFORE every fetch, tolerates exactly one network error (`URLError`), returns `nil` on timeout.
/// Cancellation (leaving the screen) always propagates.
func pollUntil<T>(
    interval: Duration,
    max: Duration,
    onEach: (T) -> Void = { _ in },
    fetch: () async throws -> T,
    done: (T) -> Bool
) async throws -> T? {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: max)
    var toleratedNetworkError = false
    while true {
        try await Task.sleep(for: interval)
        let value: T
        do {
            value = try await ipv64Retrying(fetch)
        } catch let error as URLError where error.code != .cancelled && !toleratedNetworkError {
            toleratedNetworkError = true
            if clock.now >= deadline { return nil }
            continue
        }
        onEach(value)
        if done(value) { return value }
        if clock.now >= deadline { return nil }
    }
}
