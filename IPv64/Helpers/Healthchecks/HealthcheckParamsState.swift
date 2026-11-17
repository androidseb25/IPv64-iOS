import Foundation
import IPv64

// Type-dependent parameters of the account check form (spec 02 B5; Android `ParamsState`).
// Everything is text so input stays verbatim. Pure and nonisolated.

nonisolated struct HeaderRow: Hashable, Identifiable, Sendable {
    var id = UUID()
    var key = ""
    var value = ""
}

nonisolated struct JsonRuleRow: Hashable, Identifiable, Sendable {
    var id = UUID()
    var path = ""
    var op: HC2JSONRuleOperator = .eq
    var value = ""
}

nonisolated extension HC2JSONRuleOperator {
    var needsValue: Bool { self != .exists && self != .notExists }
}

nonisolated let jsonRuleOperators: [HC2JSONRuleOperator] = [
    .eq, .ne, .lt, .le, .gt, .ge, .contains, .notContains, .regex, .exists, .notExists,
]

nonisolated let dnsRecordTypes: [HC2DNSRecordType] = [.a, .aaaa, .cname, .mx, .txt, .ns, .srv, .caa, .ptr, .soa]

nonisolated let httpMethods = ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]

nonisolated struct ParamsState: Equatable, Sendable {
    // http / keyword / json
    var method = "GET"
    var acceptStatus = ""
    var followRedirects = true
    var maxRedirects = ""
    var keyword = ""
    var keywordAbsent = false
    var basicUser = ""
    var basicPassword = ""
    var headers: [HeaderRow] = []
    var body = ""
    var insecureTls = false
    var certMinDays = ""
    // json
    var jsonRules: [JsonRuleRow] = []
    var jsonAny = false
    // dns
    var recordType: HC2DNSRecordType = .a
    var resolver: HC2DNSResolver = .system
    var server = ""
    var values = ""
    var dnssec = false
    var minTtl = ""
    // dns / tcp / port
    var expect = ""
    // icmp
    var count = ""
    var maxLossPercent = ""
    var maxLatencyMs = ""
    // tcp / port / cert
    var port = ""
    var send = ""
    var tls = false
    // cert
    var minDays = ""
    var serverName = ""
    var skipChain = false
    var skipHostname = false
    // push
    var periodValue = ""
    var periodUnit = 1
    var graceValue = ""
    var graceUnit = 1

    static func initial(_ type: HC2CheckType) -> ParamsState {
        switch type {
        case .dns: ParamsState(expect: "any")
        case .port: ParamsState(expect: "open")
        default: ParamsState()
        }
    }

    /// Loaded parameters → form state; passwords never come back.
    static func from(_ type: HC2CheckType, _ p: HC2CheckParams?) -> ParamsState {
        var s = initial(type)
        guard let p else { return s }
        let (pv, pu) = secondsToDuration(p.periodSeconds)
        let (gv, gu) = secondsToDuration(p.graceSeconds)
        s.method = p.method?.nonBlank ?? s.method
        s.acceptStatus = p.acceptStatus ?? ""
        s.followRedirects = p.followRedirects ?? s.followRedirects
        s.maxRedirects = p.maxRedirects.map(String.init) ?? ""
        s.keyword = p.keyword ?? ""
        s.keywordAbsent = p.keywordAbsent ?? false
        s.basicUser = p.basicUser ?? ""
        s.basicPassword = ""
        s.headers = (p.headers ?? [:]).sorted { $0.key < $1.key }.map { HeaderRow(key: $0.key, value: $0.value) }
        s.body = p.body ?? ""
        s.insecureTls = p.insecureTLS ?? false
        s.certMinDays = p.certMinDays.map(String.init) ?? ""
        s.jsonRules = (p.jsonRules ?? []).map { JsonRuleRow(path: $0.path, op: $0.op, value: $0.value ?? "") }
        s.jsonAny = p.jsonAny ?? false
        s.recordType = p.recordType ?? s.recordType
        s.resolver = p.resolver ?? s.resolver
        s.server = p.server ?? ""
        s.values = (p.values ?? []).joined(separator: "\n")
        s.dnssec = p.dnssec ?? false
        s.minTtl = p.minTTL.map(String.init) ?? ""
        s.expect = p.expect?.nonBlank ?? s.expect
        s.count = p.count.map(String.init) ?? ""
        s.maxLossPercent = p.maxLossPercent.map(String.init) ?? ""
        s.maxLatencyMs = p.maxLatencyMS.map(String.init) ?? ""
        s.port = p.port.map(String.init) ?? ""
        s.send = p.send ?? ""
        s.tls = p.tls ?? false
        s.minDays = p.minDays.map(String.init) ?? ""
        s.serverName = p.serverName ?? ""
        s.skipChain = p.skipChain ?? false
        s.skipHostname = p.skipHostname ?? false
        s.periodValue = pv
        s.periodUnit = pu
        s.graceValue = gv
        s.graceUnit = gu
        return s
    }

    // MARK: Request mapping

    /// Non-blank → trimmed; else "" when something was there before (clears); else not sent.
    private static func txt(_ cur: String, _ ini: String) -> String? {
        cur.nonBlank.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? (ini.nonBlank != nil ? "" : nil)
    }

    private static func int(_ s: String) -> Int? { Int(s.trimmingCharacters(in: .whitespaces)) }

    /// Parameters for the request. Password and headers are only sent when changed.
    func toParams(_ type: HC2CheckType, ini: ParamsState) -> HC2CheckParams? {
        switch type {
        case .http, .keyword, .json:
            HC2CheckParams(
                method: method.trimmingCharacters(in: .whitespaces).nonBlank,
                acceptStatus: Self.txt(acceptStatus, ini.acceptStatus),
                followRedirects: followRedirects,
                maxRedirects: Self.int(maxRedirects),
                keyword: type == .keyword ? keyword.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                keywordAbsent: type == .keyword ? keywordAbsent : nil,
                basicUser: Self.txt(basicUser, ini.basicUser),
                basicPassword: basicPassword.isEmpty ? nil : basicPassword,
                headers: headersForRequest(ini),
                body: Self.txt(body, ini.body),
                insecureTLS: insecureTls,
                certMinDays: Self.int(certMinDays),
                jsonRules: type == .json ? jsonRules.map {
                    HC2CheckParams.JSONRule(path: $0.path.trimmingCharacters(in: .whitespaces), op: $0.op,
                                            value: $0.op.needsValue ? $0.value : nil)
                } : nil,
                jsonAny: type == .json ? jsonAny : nil)
        case .dns:
            HC2CheckParams(
                expect: expect.nonBlank,
                recordType: recordType, resolver: resolver,
                server: resolver == .server ? server.trimmingCharacters(in: .whitespaces) : nil,
                values: ["contains", "equals", "regex"].contains(expect)
                    ? values.split(whereSeparator: \.isNewline)
                        .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } : nil,
                dnssec: dnssec, minTTL: Self.int(minTtl))
        case .icmp:
            HC2CheckParams(count: Self.int(count), maxLossPercent: Self.int(maxLossPercent),
                           maxLatencyMS: Self.int(maxLatencyMs))
        case .tcp:
            HC2CheckParams(port: Self.int(port), send: Self.txt(send, ini.send),
                           expect: Self.txt(expect, ini.expect), tls: tls)
        case .port:
            HC2CheckParams(port: Self.int(port), expect: expect.nonBlank)
        case .cert:
            HC2CheckParams(port: Self.int(port), minDays: Self.int(minDays),
                           serverName: Self.txt(serverName, ini.serverName),
                           skipChain: skipChain, skipHostname: skipHostname)
        case .push:
            HC2CheckParams(
                periodSeconds: durationToSeconds(periodValue, unitIdx: periodUnit).flatMap { $0 >= 0 ? $0 : nil },
                graceSeconds: durationToSeconds(graceValue, unitIdx: graceUnit).flatMap { $0 >= 0 ? $0 : nil })
        default:
            nil
        }
    }

    /// Headers only when changed (nil = server keeps them); unchanged masked placeholders are left out.
    func headersForRequest(_ ini: ParamsState) -> [String: String]? {
        let old = ini.headers.headerMap
        let now = headers.headerMap
        if now == old { return nil }
        return now.filter { !(old[$0.key] == $0.value && $0.value.looksMasked) }
    }

    /// Headers were changed although unchanged masked values are still in the list.
    func headersNeedReentry(_ ini: ParamsState) -> Bool {
        let old = ini.headers.headerMap
        let now = headers.headerMap
        return now != old && now.contains { old[$0.key] == $0.value && $0.value.looksMasked }
    }

    // MARK: Validation

    private static func inRange(_ s: String, _ range: ClosedRange<Int>) -> Bool {
        s.nonBlank == nil || (int(s).map(range.contains) ?? false)
    }

    /// Error text + whether the field is in the collapsed "Advanced" section.
    func validateIssue(_ type: HC2CheckType, target: String) -> (message: String, inAdvanced: Bool)? {
        switch type {
        case .http, .keyword, .json:
            if followRedirects && !Self.inRange(maxRedirects, 0...50) {
                return (String(localized: "Max redirects must be a number between 0 and 50."), true)
            }
            if !Self.inRange(certMinDays, 0...3650) {
                return (String(localized: "Certificate minimum days must be between 0 and 3650."), true)
            }
            if headers.contains(where: { $0.key.nonBlank == nil && $0.value.nonBlank != nil }) {
                return (String(localized: "Every header needs a name."), true)
            }
            if type == .keyword && keyword.nonBlank == nil { return (String(localized: "Please enter a keyword."), false) }
            if type == .json {
                if jsonRules.isEmpty { return (String(localized: "Add at least one JSON rule."), false) }
                if jsonRules.count > 10 { return (String(localized: "At most 10 JSON rules are allowed."), false) }
                if jsonRules.contains(where: { $0.path.nonBlank == nil }) {
                    return (String(localized: "Every JSON rule needs a path."), false)
                }
                if jsonRules.contains(where: { $0.op.needsValue && $0.value.nonBlank == nil }) {
                    return (String(localized: "Every JSON rule except exists / not exists needs a value."), false)
                }
            }
        case .dns:
            if resolver == .server && server.nonBlank == nil { return (String(localized: "Please enter a DNS server."), true) }
            if !Self.inRange(minTtl, 0...Int(Int32.max)) {
                return (String(localized: "Minimum TTL must be a number of 0 or more."), true)
            }
            if ["contains", "equals", "regex"].contains(expect) && values.nonBlank == nil {
                return (String(localized: "Please enter the expected value(s)."), true)
            }
        case .icmp:
            if !Self.inRange(count, 1...20) { return (String(localized: "Packet count must be between 1 and 20."), true) }
            if !Self.inRange(maxLossPercent, 0...100) {
                return (String(localized: "Max packet loss must be between 0 and 100."), true)
            }
            if !Self.inRange(maxLatencyMs, 0...Int(Int32.max)) {
                return (String(localized: "Max latency must be a number of 0 or more."), true)
            }
        case .tcp, .port:
            if !Self.inRange(port, 1...65535) { return (String(localized: "Port must be between 1 and 65535."), false) }
            if port.nonBlank == nil && !target.contains(":") {
                return (String(localized: "Please enter a port or use host:port as target."), false)
            }
        case .cert:
            if !Self.inRange(port, 1...65535) { return (String(localized: "Port must be between 1 and 65535."), true) }
            if !Self.inRange(minDays, 0...3650) { return (String(localized: "Minimum days must be between 0 and 3650."), true) }
        case .push:
            if durationToSeconds(periodValue, unitIdx: periodUnit) == -1 {
                return (String(localized: "Expected interval is not a valid number."), false)
            }
            if durationToSeconds(graceValue, unitIdx: graceUnit) == -1 {
                return (String(localized: "Grace period is not a valid number."), false)
            }
        default:
            break
        }
        return nil
    }
}

nonisolated extension HC2CheckType {
    /// Types with core parameters shown in the main form.
    var hasEssentialParams: Bool { [.keyword, .json, .dns, .tcp, .port, .push].contains(self) }
    /// Types with fine options (inside "Advanced").
    var hasAdvancedParams: Bool { ![.whois, .push].contains(self) }
}

private nonisolated extension [HeaderRow] {
    var headerMap: [String: String] {
        var map: [String: String] = [:]
        for row in self where row.key.nonBlank != nil {
            map[row.key.trimmingCharacters(in: .whitespaces)] = row.value
        }
        return map
    }
}

private nonisolated extension String {
    var looksMasked: Bool {
        hasPrefix("…")
            || (count >= 3 && (allSatisfy { "*•●".contains($0) } || lowercased() == "<redacted>" || lowercased() == "[redacted]"))
    }
}
