import Foundation
import IPv64

/// Healthchecks 2.0 data of the widget account (Keychain `API_KEY_WIDGET`).
nonisolated enum ApiServiceWidget {
    static let maxBars = 20

    /// Checks with their recent state changes; nil when there is no key or the check list cannot be loaded.
    @concurrent
    static func fetchChecks() async -> [WidgetCheck]? {
        guard let key = try? SecureStore.readString("API_KEY_WIDGET"), !key.isEmpty else { return nil }
        let api = IPv64(apiKey: key)
        do {
            async let checks = api.hc2.checks.list()
            // Events only decorate the bars; a failure still yields the current state.
            async let events = try? api.hc2.events(limit: 100).items
            let (list, recent) = try await (checks, events ?? [])
            // The key may have changed while the request ran.
            guard key == (try? SecureStore.readString("API_KEY_WIDGET")) else { return nil }
            var byToken: [String: [String]] = [:]
            for event in recent {
                guard let token = event.token, let state = event.toState else { continue }
                byToken[token, default: []].append(state)
            }
            return list.map { check in
                var states = Array((byToken[check.token] ?? []).prefix(maxBars))
                if states.isEmpty { states = [check.paused == true ? "paused" : check.state?.state?.rawValue ?? "pending"] }
                return WidgetCheck(token: check.token, name: check.name ?? check.token, states: states)
            }
        } catch {
            return nil
        }
    }
}
