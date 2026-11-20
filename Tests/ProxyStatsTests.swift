// Run: Tests/run-proxy-stats-tests.sh — checks the hourly gap filling and the "answered" formula of the Proxy64 chart.
import Foundation

@main
struct ProxyStatsTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_000_000 * 3600 + 1234) // inside hour 1_000_000
        let hour = Date(timeIntervalSince1970: 999_998 * 3600)
        let row = ProxyStats.Row(hour: hour, requests: 100, c4: 5, c5: 2, bytes: 10, bytesIn: 3, blocked: 20, decoy: 7, connBlocked: 4)
        let pts = ProxyStats.series([row], hours: 4, now: now)
        precondition(pts.count == 4 && pts.last?.time == Date(timeIntervalSince1970: 1_000_000 * 3600))
        precondition(pts[0].time == Date(timeIntervalSince1970: 999_997 * 3600) && pts[0].ok == 0 && pts[0].bytes == 0) // gap
        // ok = 100 - (20 - 4) - 7 - 5 - 2 = 70
        precondition(pts[1].ok == 70 && pts[1].blocked == 20 && pts[1].up == 3 && pts[1].err == 2)
        precondition(pts[2].requests == 0 && pts[3].ok == 0)
        // Old hours that counted rejected under 4xx never go negative.
        let old = ProxyStats.Row(hour: hour, requests: 1, c4: 5)
        precondition(ProxyStats.series([old], hours: 3, now: now)[1].ok == 0)
    }
}
