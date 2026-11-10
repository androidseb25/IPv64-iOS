import Foundation
import Testing
@testable import IPv64_net

struct Dns64LogicTests {
    @Test(arguments: [(0.0, 1), (119.9, 1), (120.0, 30), (3600.0, 30)])
    func countdownInterval(remaining: Double, seconds: Int) {
        #expect(dns64CountdownInterval(remaining: remaining) == .seconds(seconds))
    }

    @Test func queryStatusFilter() {
        #expect(Dns64LogFilter.all.rawStatus == nil)
        #expect(Dns64LogFilter.blocked.rawStatus == "blocked")
        #expect(Dns64LogFilter.allowed.rawStatus == "allowed")
    }

    @Test func chartBuckets() {
        let bars = dns64Bars([(t: 1000, total: 10, blocked: 3), (t: nil, total: 2, blocked: 5), (t: 2000, total: nil, blocked: nil)])
        #expect(bars.map(\.allowed) == [7, 0, 0])
        #expect(bars.map(\.blocked) == [3, 5, 0])
        #expect(bars.map(\.total) == [10, 5, 0])
        #expect(bars[0].start == Date(timeIntervalSince1970: 1))
        #expect(bars[1].start == nil)
        #expect(dns64MaxBar(bars) == 10)
        #expect(dns64MaxBar([]) == 1)
    }

    @Test(arguments: [(0, [Int]()), (1, [0]), (2, [0, 1]), (10, [0, 3, 6, 9])])
    func axisIndices(count: Int, expected: [Int]) {
        #expect(dns64AxisIndices(count: count) == expected)
    }

    @Test func perHourAndStatusChip() {
        #expect(dns64PerHour(total: 100, hours: 24) == 4)
        #expect(dns64PerHour(total: 100, hours: 0) == 0)
        #expect(dns64StatusChip("blocked").tone == .red)
        #expect(dns64StatusChip("error").tone == .orange)
        #expect(dns64StatusChip("cached") == ("Cached", .green))
        #expect(dns64StatusChip(nil) == ("–", .gray))
    }
}

struct ProxyLogicTests {
    /// Tolerates a comma decimal separator of the simulator locale.
    private func n(_ s: String) -> String { s.replacingOccurrences(of: ",", with: ".") }
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    @Test(arguments: [(0.5, "512.0 MB"), (1.0, "1.00 GB"), (1.2, "1.20 GB"), (999.0, "999.00 GB"), (1024.0, "1.0 TB"), (20_480.0, "20.0 TB")])
    func gbText(gb: Double, expected: String) {
        #expect(n(ProxyLogic.gbText(gb)) == expected)
    }

    @Test(arguments: [(0.5, "0.5 MB"), (1024.0, "1.00 GB"), (1_048_576.0, "1.0 TB")])
    func megabytes(mb: Double, expected: String) {
        #expect(n(ProxyLogic.formatMegabytes(mb)) == expected)
    }

    @Test func quotaUnlimitedShowsInfinity() {
        let s = ProxyLogic.quotaStats(domainsUsed: 3, domainsLimit: 0, oldCDN: nil, trafficUsedMB: 512, trafficLimitMB: 0, bandwidthMbit: 0, now: fixedNow)
        #expect(s.domains == "3 / ∞" && s.domainFraction == nil)
        #expect(n(s.traffic) == "512.0 MB / ∞" || n(s.traffic).hasSuffix("/ ∞"))
        #expect(s.trafficFraction == nil)
        #expect(s.trafficHint?.contains("Bandwidth: unlimited") == true)
    }

    @Test func quotaConvertsMegabytesToGbAndTb() {
        let s = ProxyLogic.quotaStats(domainsUsed: 2, domainsLimit: 4, oldCDN: 1, trafficUsedMB: 2048, trafficLimitMB: 1_048_576,
                                      bandwidthMbit: 100, now: fixedNow)
        #expect(s.domains == "2 / 4" && s.domainFraction == 0.5)
        #expect(s.domainHint == "1 in the old CDN")
        #expect(n(s.traffic) == "2.00 GB / 1.0 TB")
        #expect(s.trafficFraction == 2048.0 / 1_048_576.0)
        #expect(s.trafficHint?.contains("Bandwidth: 100 Mbit/s") == true)
    }

    @Test func usageStatsIsAlreadyInGb() {
        let s = ProxyLogic.usageStats(domainsUsed: 1, domainsLimit: 5, trafficUsedGB: 1.5, trafficLimitGB: 2048, now: fixedNow)
        #expect(n(s.traffic) == "1.50 GB / 2.0 TB")
        #expect(s.trafficFraction == 1.5 / 2048)
        #expect(ProxyLogic.usageStats(domainsUsed: nil, domainsLimit: nil, trafficUsedGB: nil, trafficLimitGB: nil, now: fixedNow).domains == "0 / ∞")
    }

    @Test func forecastNeedsOneDayOfData() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        let early = cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
        let mid = cal.date(from: DateComponents(year: 2026, month: 11, day: 11))!   // 10 elapsed days of 30
        #expect(ProxyLogic.forecastGB(used: 5, now: early, calendar: cal) == nil)
        #expect(ProxyLogic.forecastGB(used: 0, now: mid, calendar: cal) == nil)
        #expect(ProxyLogic.forecastGB(used: 10, now: mid, calendar: cal) == 30)
    }

    @Test func availability() {
        #expect(ProxyLogic.availability(counterPresent: false, used: 5, limit: 0) == .unknown)
        #expect(ProxyLogic.availability(counterPresent: true, used: 5, limit: nil) == .available)
        #expect(ProxyLogic.availability(counterPresent: true, used: 0, limit: 0) == .notInPlan)
        #expect(ProxyLogic.availability(counterPresent: true, used: 2.2, limit: 3) == .limitReached(used: 3, limit: 3))
        #expect(ProxyLogic.availability(counterPresent: true, used: 2, limit: 3) == .available)
        #expect(ProxyLogic.Availability.unknown.canCreate && !ProxyLogic.Availability.notInPlan.canCreate)
    }

    @Test func smallHelpers() {
        #expect(ProxyLogic.displayName(domain: " ", id: "abcdef") == "Domain …cdef")
        #expect(ProxyLogic.trafficText(incoming: nil, outgoing: nil, present: false) == "–")
        #expect(ProxyLogic.firstEnableError([(name: "a", failed: false, error: nil, code: nil), (name: "b", failed: true, error: nil, code: "E1")]) == "b: E1")
        #expect(ProxyLogic.firstEnableError([]) == nil)
        #expect(ProxyLogic.isIPv4("255.255.255.255") && !ProxyLogic.isIPv4("01.1.1.1"))
    }
}

struct FormatterTests {
    private func n(_ s: String) -> String { s.replacingOccurrences(of: ",", with: ".") }

    @Test func goZeroDateIsNil() {
        let goZero = Date(timeIntervalSince1970: -62_135_596_800)
        #expect(Formatters.realOrNil(goZero) == nil)
        #expect(Formatters.realOrNil(Date(timeIntervalSince1970: 0)) == nil)
        #expect(Formatters.realOrNil(nil) == nil)
        #expect(Formatters.realOrNil(Date(timeIntervalSince1970: 1)) != nil)
        #expect(Formatters.germanTime(goZero, fallback: "none") == "none")
        #expect(Formatters.ago(goZero) == nil)
        #expect(Formatters.parseISO("0001-01-01T00:00:00Z") == nil)
    }

    @Test func parseISOHandlesFractionsOffsetsAndGarbage() {
        #expect(Formatters.parseISO("2026-11-04T06:03:15.891Z") == Date(timeIntervalSince1970: 1_793_772_195.891))
        #expect(Formatters.parseISO("2026-11-04T07:03:15+01:00") == Date(timeIntervalSince1970: 1_793_772_195))
        #expect(Formatters.parseISO(" ") == nil && Formatters.parseISO(nil) == nil && Formatters.parseISO("x") == nil)
    }

    @Test func germanDateFormatsUseDeviceTimeZone() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let date = try #require(cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 7, minute: 8, second: 9)))
        #expect(Formatters.german(date) == "05.03.2026")
        #expect(Formatters.germanTime(date) == "05.03.2026 07:08:09")
        #expect(Formatters.clock(date) == "07:08:09")
    }

    @Test(arguments: [(0, "0 B"), (512, "512 B"), (1023, "1023 B"), (1024, "1.0 KB"), (1536, "1.5 KB"), (1_572_864, "1.5 MB"),
                      (1_073_741_824, "1.0 GB"), (1_099_511_627_776, "1.0 TB")] as [(Int64, String)])
    func bytes(value: Int64, expected: String) {
        #expect(n(Formatters.bytes(value)) == expected)
    }

    @Test(arguments: [(-5, "0 s"), (0, "0 s"), (45, "45 s"), (60, "1 min"), (90, "1 min 30 s"), (5400, "1 h 30 min"), (3600, "1 h"),
                      (90_061, "1 d 1 h"), (86_400 * 3, "3 d")])
    func duration(seconds: Int, expected: String) {
        #expect(Formatters.duration(seconds: seconds) == expected)
    }

    @Test func percentLatencyUsage() {
        #expect(n(Formatters.percent(99.95)) == "99.95 %" && Formatters.percent(nil) == "–")
        #expect(n(Formatters.percent(100)) == "100 %")
        #expect(n(Formatters.latency(4.5)) == "4.5 ms" && n(Formatters.latency(12.4)) == "12 ms" && Formatters.latency(nil) == "–")
        #expect(n(Formatters.usage(1.236)) == "1.24" && n(Formatters.usage(3)) == "3")
    }

    @Test func relativeThresholds() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func r(_ seconds: Double) -> String { Formatters.relative(now.addingTimeInterval(-seconds), now: now) }
        #expect(r(30) == r(0) && r(59) == r(0))
        #expect(r(60).contains("1") && r(3599).contains("59"))
        #expect(r(3600).contains("1") && r(86_399).contains("23"))
        #expect(r(86_400).contains("1") && r(29 * 86_400).contains("29"))
        #expect(r(30 * 86_400) == Formatters.german(now.addingTimeInterval(-30 * 86_400)))
        #expect(Formatters.relative(now.addingTimeInterval(10), now: now) == Formatters.germanTime(now.addingTimeInterval(10)))
    }

    @Test func repeatMinutesAndNodeName() {
        #expect(Formatters.repeatMinutes(nil) == "–")
        #expect(Formatters.repeatMinutes(90) == "1 h 30 min")
        #expect(Formatters.nodeName("  ", nodeId: "abcdef12") == "Node …ef12")
        #expect(Formatters.nodeName("Home", nodeId: "x") == "Home")
    }
}
