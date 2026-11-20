import Foundation

/// Hourly Proxy64 traffic series (port of Node64 `cdn64-chart.js series()`); Foundation only so Tests/ can compile it alone.
nonisolated enum ProxyStats {
    /// One `timeline` row of `/cdn64/stats`; missing keys are 0.
    struct Row: Equatable {
        var hour: Date
        var requests = 0.0, c4 = 0.0, c5 = 0.0, bytes = 0.0, bytesIn = 0.0, blocked = 0.0, decoy = 0.0, connBlocked = 0.0
    }

    struct Point: Equatable, Identifiable {
        var time: Date
        var ok = 0.0, c4 = 0.0, err = 0.0, blocked = 0.0, decoy = 0.0, requests = 0.0, bytes = 0.0, up = 0.0
        var id: Date { time }
    }

    /// Every hour of the range up to the current hour, oldest first; hours without a row are all zero.
    static func series(_ rows: [Row], hours: Int, now: Date = .now) -> [Point] {
        let hour = 3600.0
        let current = (now.timeIntervalSince1970 / hour).rounded(.down) * hour
        let byHour = Dictionary(rows.map { ($0.hour.timeIntervalSince1970, $0) }, uniquingKeysWith: { $1 })
        return (0..<max(hours, 0)).reversed().map { i in
            let t = current - Double(i) * hour
            let r = byHour[t]
            let blocked = r?.blocked ?? 0, conn = r?.connBlocked ?? 0, decoy = r?.decoy ?? 0
            let c4 = r?.c4 ?? 0, err = r?.c5 ?? 0, req = r?.requests ?? 0
            // requests include rejected and honeypot requests, not rejected connections; never below 0 for old hours
            return Point(time: Date(timeIntervalSince1970: t), ok: max(0, req - (blocked - conn) - decoy - c4 - err),
                         c4: c4, err: err, blocked: blocked, decoy: decoy, requests: req,
                         bytes: r?.bytes ?? 0, up: r?.bytesIn ?? 0)
        }
    }
}
