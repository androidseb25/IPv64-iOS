import SwiftUI
import IPv64

/// ipv64.net network numbers, charts and rankings. Empty sections stay hidden.
struct HoneypotNetworkSections: View {
    let stats: ThreatStats

    var body: some View {
        Section {
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    MoreKpiTile("Sensors online", (stats.sensors?.online ?? 0).formatted())
                    MoreKpiTile("Attacks (24 h)", (stats.attacks24h?.events ?? 0).formatted())
                }
                Divider()
                GridRow {
                    MoreKpiTile("Attacker IPs (24 h)", (stats.attacks24h?.sources ?? 0).formatted())
                    MoreKpiTile("Blocklist size", (stats.lists?["v64"] ?? 0).formatted())
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("ipv64.net network")
        }
        let days = DayValue.parse((stats.timeline ?? []).map { ($0.day, $0.events) })
        if !days.isEmpty { Section("Attacks per day (30 days)") { DayLineChart(days: days, color: .blue) } }
        ranking("Most attacked ports (7 days)", (stats.topPorts ?? []).map {
            ("\($0.service ?? "–") · \($0.port.map(String.init) ?? "–")", $0.events ?? 0, nil, false)
        })
        ranking("Most frequent attack kinds (7 days)", (stats.topKinds ?? []).map { ($0.kind ?? "–", $0.events ?? 0, nil, false) })
        if let top = stats.top {
            ranking("Origin of blocklist IPs", (top.countries ?? []).map {
                (MoreLogic.countryFlag($0.country) ?? "–", $0.ips ?? 0, String(localized: "\($0.ips ?? 0) IPs"), false)
            })
            entries("User names", top.usernames, mono: true)
            entries("Passwords", top.passwords, mono: true)
            entries("Requested paths", top.paths, mono: true)
            entries("User agents", top.userAgents, mono: false)
            entries("Fingerprints (JA4/HASSH)", top.fingerprints, mono: true)
        }
        if let lists = stats.lists, !lists.isEmpty {
            Section("List sizes") {
                ForEach(lists.sorted { $0.key < $1.key }, id: \.key) { key, value in
                    LabeledContent(MoreLogic.prettyKey(key), value: value.formatted())
                }
            }
        }
        if stats.threshold?.accounts != nil || stats.info?.nonBlank != nil || stats.license?.nonBlank != nil {
            Section {} footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let accounts = stats.threshold?.accounts {
                        Text("Rankings and lists need at least \(accounts) reporting accounts.")
                    }
                    if let info = stats.info?.nonBlank { Text(verbatim: info) }
                    if let license = stats.license?.nonBlank { Text("License: \(license)") }
                }
            }
        }
    }

    private func entries(_ title: LocalizedStringKey, _ list: [ThreatStatsEntry]?, mono: Bool) -> some View {
        ranking(title, (list ?? []).compactMap { entry in
            guard let value = entry.value?.nonBlank else { return nil }
            var details = [String(localized: "\(entry.events ?? 0) attempts")]
            if let accounts = entry.accounts { details.append(String(localized: "\(accounts) acc.")) }
            return (value, entry.events ?? 0, details.joined(separator: " · "), mono)
        })
    }

    @ViewBuilder private func ranking(_ title: LocalizedStringKey,
                                      _ rows: [(label: String, value: Int, detail: String?, mono: Bool)]) -> some View {
        if !rows.isEmpty {
            let maxValue = rows.map(\.value).max() ?? 0
            Section(title) {
                ForEach(rows.indices, id: \.self) { i in
                    ModuleRankRow(label: rows[i].label, value: rows[i].value,
                                  detail: rows[i].detail ?? rows[i].value.formatted(), maxValue: maxValue, mono: rows[i].mono)
                }
            }
        }
    }
}

/// Share of the own nodes that run the honeypot module.
struct HoneypotNodeShare: View {
    let nodes: [HC2Node]

    var body: some View {
        if !nodes.isEmpty {
            let share = MoreLogic.honeypotShare(modules: nodes.map { $0.modules ?? [] })
            Section("Your nodes") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(share.active) of \(share.total) nodes run the honeypot").font(.subheadline.weight(.semibold))
                    ProgressView(value: share.fraction).tint(.orange)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Own contribution: numbers, daily chart and sensors.
struct HoneypotContributionSections: View {
    let stats: HoneypotStats
    let sensors: [HoneypotSensor]

    var body: some View {
        Section {
            HStack {
                Text("Your contribution").font(.headline)
                Spacer()
                if stats.contributor == true { MoreTag(String(localized: "Contributor"), .green) }
                else { MoreTag(String(localized: "Not contributing"), .gray) }
            }
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    MoreKpiTile("Sensors online", "\(stats.sensorsOnline ?? 0) / \(stats.sensors ?? 0)")
                    MoreKpiTile("Events (24 h)", (stats.events24h ?? 0).formatted())
                }
                Divider()
                GridRow {
                    MoreKpiTile("Events (7 d)", (stats.events7d ?? 0).formatted())
                    MoreKpiTile("Sources (24 h)", (stats.sources24h ?? 0).formatted())
                }
                Divider()
                GridRow {
                    MoreKpiTile("Sources (7 d)", (stats.sources7d ?? 0).formatted())
                    Color.clear.frame(height: 0)
                }
            }
            .padding(.vertical, 4)
        } footer: {
            if let last = HcFormat.real(stats.lastReport) {
                Text("Last report \(last.formatted(.relative(presentation: .named)))")
            }
        }
        let days = DayValue.parse((stats.timeline ?? []).map { ($0.day, $0.events) })
        if !days.isEmpty { Section("Events per day (7 days)") { DayLineChart(days: days, color: .orange) } }
        if !sensors.isEmpty {
            Section("Sensors") {
                ForEach(sensors) { sensor in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(verbatim: MoreLogic.sensorTitle(sensor.id)).font(.headline)
                            Spacer(minLength: 8)
                            if sensor.disabled == true { MoreTag(String(localized: "Disabled"), .gray) }
                            else if sensor.online == true { MoreTag(String(localized: "Online"), .green) }
                            else { MoreTag(String(localized: "Offline"), .red) }
                        }
                        Text(verbatim: subtitle(sensor)).font(.footnote).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func subtitle(_ s: HoneypotSensor) -> String {
        var lines: [String] = []
        let profile = [s.profile, s.mode, s.version.map { "v\($0)" }].compactMap { $0?.nonBlank }.joined(separator: " · ")
        if !profile.isEmpty { lines.append(String(localized: "Profile: \(profile)")) }
        if let last = HcFormat.real(s.lastSeen) {
            lines.append(String(localized: "Last report \(last.formatted(.relative(presentation: .named)))"))
        }
        lines.append(String(localized: "Reports: \(s.reports ?? 0)"))
        lines.append(String(localized: "Events (24 h / 7 d): \(s.events24h ?? 0) / \(s.events7d ?? 0)"))
        lines.append(String(localized: "Sources (24 h / 7 d): \(s.sources24h ?? 0) / \(s.sources7d ?? 0)"))
        return lines.joined(separator: "\n")
    }
}
