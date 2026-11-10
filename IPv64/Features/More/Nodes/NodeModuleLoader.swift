import Foundation
import IPv64

// Data of the node module screen (spec 04 §4.2). Sections are plain values so the view only draws.

nonisolated struct ModRow: Sendable {
    var title: String
    var subtitle: String?
    var chip: Chip?

    struct Chip: Sendable {
        let text: String
        let tone: Tone
    }
}

nonisolated enum Tone: Sendable { case green, red, orange, gray }

nonisolated struct RankRow: Sendable {
    var label: String
    var value: Int
    var detail: String
}

nonisolated struct ModSection: Sendable, Identifiable {
    enum Kind: Sendable {
        case error(String)
        case facts([(String, String)])
        case stats([(String, String)])
        case rows([ModRow], empty: String)
        case bars([(label: String, value: Int)])
        case ranks([RankRow], mono: Bool)
    }

    let id: Int
    let title: String
    let kind: Kind
}

nonisolated enum NodeModuleLoader {
    private static let top = 10

    /// All sections of a module, loaded in parallel; a failing section shows its error inline.
    static func load(_ node: Node64, module: String) async -> [ModSection] {
        let jobs = sections(node, module: module)
        return await withTaskGroup(of: (Int, ModSection?).self) { group in
            for (index, job) in jobs.enumerated() {
                group.addTask { (index, await job()) }
            }
            var result: [(Int, ModSection)] = []
            for await (index, section) in group { if let section { result.append((index, section)) } }
            return result.sorted { $0.0 < $1.0 }.map { ModSection(id: $0.0, title: $0.1.title, kind: $0.1.kind) }
        }
    }

    private typealias Job = @Sendable () async -> ModSection?

    private static func sections(_ node: Node64, module: String) -> [Job] {
        switch module.lowercased() {
        case "honeypot": honeypot(node)
        case "dns64": dns64(node)
        case "cdn64": [guarded("Hosts") {
            .rows(try await node.proxy64.hosts.list().map(hostRow), empty: String(localized: "No hosts."))
        }]
        case "dyndns": [guarded("Targets") {
            .rows(try await node.dyndns.targets.list().map(targetRow), empty: String(localized: "No targets."))
        }]
        default: [guarded("Checks") {
            .rows(try await node.hc.checks.list().map(checkRow), empty: String(localized: "No checks."))
        }]
        }
    }

    /// One section; errors become an inline error section.
    private static func guarded(_ title: String, _ build: @escaping @Sendable () async throws -> ModSection.Kind) -> Job {
        { await make(title, build) }
    }

    private static func make(_ title: String, _ build: () async throws -> ModSection.Kind) async -> ModSection {
        do {
            return ModSection(id: 0, title: title, kind: try await build())
        } catch {
            return ModSection(id: 0, title: title, kind: .error(errorText(error)))
        }
    }

    private static func errorText(_ error: any Error) -> String {
        if case .api(let e)? = error as? Node64Error, e.status == 404 { return String(localized: "Not available on this node.") }
        if case .httpStatus(404, _)? = error as? Node64Error { return String(localized: "Not available on this node.") }
        return ErrorText.node(error).titledText
    }

    // MARK: Rows

    private static func capitalized(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    private static func hostRow(_ h: Node64.ProxyHost) -> ModRow {
        let chip: ModRow.Chip = if h.enabled == false { .init(text: String(localized: "Disabled"), tone: .gray) }
        else if h.reach?.state == .up { .init(text: String(localized: "Up"), tone: .green) }
        else if h.reach?.state == .slow { .init(text: String(localized: "Slow"), tone: .orange) }
        else if h.reach?.state == .down { .init(text: String(localized: "Down"), tone: .red) }
        else { .init(text: String(localized: "Enabled"), tone: .gray) }
        let target = h.targetHost.map { host in h.targetPort.map { "\(host):\($0)" } ?? host }
        return ModRow(title: (h.names ?? []).joined(separator: ", ").nonBlank ?? "–",
                      subtitle: [h.kind?.rawValue, target].compactMap { $0?.nonBlank }.joined(separator: " → "), chip: chip)
    }

    private static func targetRow(_ t: Node64.DynDNSTarget) -> ModRow {
        let ok = t.status == .ok
        let parts = [t.lastIPv4, t.lastIPv6, Formatters.ago(t.lastOKAt).map { String(localized: "updated \($0)") },
                     ok ? nil : t.lastError].compactMap { $0?.nonBlank }
        let tone: Tone = ok ? .green : (t.status == .error ? .red : .gray)
        return ModRow(
            title: t.fqdn?.nonBlank ?? [t.host, t.domain].compactMap { $0 }.joined(separator: ".").nonBlank ?? "–",
            subtitle: parts.joined(separator: " · "),
            chip: .init(text: t.status.map { capitalized($0.rawValue) } ?? "–", tone: tone))
    }

    private static func checkRow(_ c: Node64.Check) -> ModRow {
        let state = c.state?.state
        let tone: Tone = switch state {
        case .up: .green
        case .down: .red
        case .degraded: .orange
        default: .gray
        }
        return ModRow(title: c.name ?? "–",
                      subtitle: Formatters.ago(Formatters.parseISO(c.state?.lastCheckAt)).map { String(localized: "checked \($0)") },
                      chip: .init(text: state.map { capitalized($0.rawValue) } ?? "–", tone: tone))
    }

    // MARK: Honeypot

    private static func rankRows(_ counts: [Node64.Honeypot64Count]?) -> [RankRow] {
        (counts ?? []).map { RankRow(label: $0.key ?? "–", value: $0.count ?? 0, detail: Formatters.count($0.count ?? 0)) }
    }

    private static func honeypot(_ node: Node64) -> [Job] {
        // One shared request; its failure is a value so siblings are not cancelled.
        let stats = Task { try await node.honeypot.stats(top: top) }
        func fromStats(_ title: String, always: Bool = false, mono: Bool = false,
                       _ rows: @escaping @Sendable (Node64.Honeypot64Stats) -> [RankRow]) -> Job {
            {
                guard let s = try? await stats.value else { return nil }
                let list = rows(s)
                return always || !list.isEmpty ? ModSection(id: 0, title: title, kind: .ranks(Array(list.prefix(top)), mono: mono)) : nil
            }
        }
        return [
            guarded("Status") {
                let s = try await node.honeypot.status()
                return .facts([
                    (String(localized: "State"), s.running == true ? String(localized: "Running") : String(localized: "Not running")),
                    (String(localized: "Version"), s.version ?? ""), (String(localized: "Profile"), s.profile ?? ""),
                    (String(localized: "Services"), "\((s.services ?? []).count)"),
                    (String(localized: "Connections"), s.counters?.connections.map(String.init) ?? ""),
                    (String(localized: "Logins"), s.counters?.logins.map(String.init) ?? ""),
                ].filter { !$0.1.isEmpty })
            },
            guarded("Last 24 hours") {
                let s = try await stats.value
                return .stats([(String(localized: "Events"), "\(s.events ?? 0)"), (String(localized: "Sources"), "\(s.sources ?? 0)"),
                               (String(localized: "Logins"), "\(s.logins ?? 0)")])
            },
            {
                guard let s = try? await stats.value, let timeline = s.timeline, !timeline.isEmpty else { return nil }
                return ModSection(id: 0, title: String(localized: "Attacks (last 24 h)"), kind: .bars(timeline.map {
                    (label: $0.time.map(hourLabel) ?? "–", value: $0.events ?? 0)
                }))
            },
            fromStats("Top attackers", always: true) { s in
                (s.topSources ?? []).map {
                    RankRow(label: $0.key ?? "–", value: $0.count ?? 0,
                            detail: [Formatters.count($0.count ?? 0), countryFlagEmoji($0.country)].compactMap { $0 }.joined(separator: " · "))
                }
            },
            fromStats("Top ports", always: true) { rankRows($0.byPort) },
            fromStats("Top countries", always: true) { s in
                (s.byCountry ?? []).map {
                    RankRow(label: countryFlagEmoji($0.key) ?? "–", value: $0.count ?? 0,
                            detail: "\(Formatters.count($0.count ?? 0)) · \($0.sources ?? 0) sources")
                }
            },
            fromStats("Services") { rankRows($0.byService) },
            fromStats("Attack kinds") { rankRows($0.byKind) },
            fromStats("Usernames", mono: true) { rankRows($0.topUsers) },
            fromStats("Passwords", mono: true) { rankRows($0.topPasswords) },
            fromStats("Paths", mono: true) { rankRows($0.topPaths) },
            fromStats("User agents") { rankRows($0.topUserAgents) },
            guarded("Recent events") {
                .rows(try await node.honeypot.events(limit: 20).map { e in
                    ModRow(title: e.src ?? "–", subtitle: [Formatters.ago(e.time), e.service ?? e.port.map { "port \($0)" },
                                                          countryFlagEmoji(e.country)].compactMap { $0?.nonBlank }.joined(separator: " · "))
                }, empty: String(localized: "No events yet."))
            },
        ]
    }

    private static func hourLabel(_ date: Date) -> String {
        date.formatted(Date.VerbatimFormatStyle(format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
                                                 timeZone: .current, calendar: Calendar(identifier: .gregorian)))
    }

    // MARK: DNS64

    private static func dns64(_ node: Node64) -> [Job] {
        var jobs: [Job] = [
            guarded("Status") {
                let s = try await node.dns64.status()
                return .facts([
                    (String(localized: "Version"), s.version ?? ""), (String(localized: "Listen"), s.listen ?? ""),
                    (String(localized: "Filtering"), s.blocking?.paused == true ? String(localized: "Paused") : String(localized: "Active")),
                    (String(localized: "Running since"), Formatters.realOrNil(s.startedAt).map(Formatters.germanTime) ?? ""),
                ].filter { !$0.1.isEmpty })
            },
            guarded("Last 24 hours") {
                let s = try await node.dns64.summary(range: .last24Hours).summary
                let total = s?.total ?? 0, blocked = s?.blocked ?? 0
                return .stats([(String(localized: "Queries"), "\(total)"), (String(localized: "Blocked"), "\(blocked)"),
                               (String(localized: "Blocked %"), blockedPercent(total: total, blocked: blocked)),
                               (String(localized: "Clients"), "\(s?.clients ?? 0)")])
            },
        ]
        let tops: [(String, Node64.DNS64TopKind)] = [("Top blocked domains", .blocked), ("Top queried domains", .allowed), ("Top clients", .clients)]
        for (title, kind) in tops {
            jobs.append(guarded(title) {
                .rows(try await node.dns64.top(kind: kind, range: .last24Hours, limit: top).map {
                    ModRow(title: $0.name ?? $0.hostname ?? "–", subtitle: $0.name != nil ? $0.hostname : nil,
                           chip: .init(text: "\($0.count ?? 0)", tone: .gray))
                }, empty: String(localized: "No data yet."))
            })
        }
        return jobs
    }

    /// Blocked share: <10 → one decimal, else integer; "–" without queries.
    static func blockedPercent(total: Int, blocked: Int) -> String {
        guard total > 0 else { return "–" }
        let p = Double(blocked) * 100 / Double(total)
        return p < 10 ? p.formatted(.number.precision(.fractionLength(1))) + " %" : "\(Int(p)) %"
    }
}
