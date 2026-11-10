import Foundation
import SwiftUI
import IPv64
import SwiftyBeaver

/// What the widget needs of a healthchecks 2.0 check: name plus the state history (newest first, raw `HC2CheckState` values).
nonisolated struct WidgetCheck: Codable, Hashable, Sendable {
    let token: String
    let name: String
    let states: [String]
}

nonisolated enum WidgetState {
    static func color(_ state: String) -> Color {
        switch state {
        case "up": .green
        case "down": .red
        case "degraded", "flapping": .orange
        case "paused": .teal
        default: .gray
        }
    }
}

nonisolated enum WidgetAPI {
    static let maxBars = 20

    /// Checks with their recent state changes; nil when there is no key or the check list cannot be loaded.
    static func fetchChecks() async -> [WidgetCheck]? {
        guard let key = try? SecureStore.readString("API_KEY_WIDGET"), !key.isEmpty else { return nil }
        let api = IPv64(apiKey: key)
        do {
            async let checks = api.hc2.checks.list()
            // Events only decorate the bars; a failure still yields the current state.
            async let events = try? api.hc2.events(limit: 200).items
            let (list, recent) = try await (checks, events ?? [])
            // The key may have changed while the request ran.
            guard key == (try? SecureStore.readString("API_KEY_WIDGET")) else { return nil }
            let byToken = Dictionary(grouping: recent.filter { $0.token != nil && $0.toState != nil }, by: { $0.token! })
            return list.map { check in
                var states = (byToken[check.token] ?? []).prefix(maxBars).compactMap(\.toState)
                if states.isEmpty { states = [check.state?.state?.rawValue ?? "pending"] }
                return WidgetCheck(token: check.token, name: check.name ?? check.token, states: Array(states))
            }
        } catch {
            iLogger.log.error("Widget checks failed: \(error)")
            return nil
        }
    }
}
