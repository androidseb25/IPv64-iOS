import SwiftUI
import IPv64

/// Shared stats content without overview (spec 04 §10.2).
struct ThreatStatsSections: View {
    let stats: ThreatStats

    var body: some View {
        let days = (stats.timeline ?? []).compactMap { d in d.day.map { DayValue(day: $0, value: d.events ?? 0) } }
        if !days.isEmpty {
            Section("Attacks per day (30 days)") { DayBarChart(days: days, color: .ipv64Blue) }
        }
        RankingSection(title: "Most attacked ports (7 days)", entries: (stats.topPorts ?? []).map {
            RankingEntry(label: "\($0.service ?? "–") · \($0.port.map(String.init) ?? "–")", value: $0.events ?? 0)
        })
        RankingSection(title: "Most frequent attack kinds (7 days)", entries: (stats.topKinds ?? []).map {
            RankingEntry(label: $0.kind ?? "–", value: $0.events ?? 0)
        })
        if let top = stats.top {
            RankingSection(title: "Origin of blocklist IPs", entries: (top.countries ?? []).map {
                RankingEntry(label: SecurityLogic.countryFlag($0.country) ?? "–", value: $0.ips ?? 0,
                             detail: String(localized: "\($0.ips ?? 0) IPs"))
            })
            Section {} header: { Text("Top 10 (\(stats.windowDays ?? 30) days)") }
            ranking("User names", top.usernames, mono: true)
            ranking("Passwords", top.passwords, mono: true)
            ranking("Requested paths", top.paths, mono: true)
            ranking("User agents", top.userAgents, mono: false)
            ranking("Fingerprints (JA4/HASSH)", top.fingerprints, mono: true)
        }
        if let lists = stats.lists, !lists.isEmpty {
            Section("List sizes") {
                ForEach(lists.sorted { $0.key < $1.key }, id: \.key) { key, value in
                    LabeledContent(SecurityLogic.prettyKey(key)) { Text(verbatim: Formatters.count(value)) }
                }
            }
        }
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

    private func ranking(_ title: LocalizedStringKey, _ entries: [ThreatStatsEntry]?, mono: Bool) -> some View {
        RankingSection(title: title, entries: (entries ?? []).compactMap { entry in
            guard let value = entry.value?.nonBlank else { return nil }
            var details = [String(localized: "\(entry.events ?? 0) attempts")]
            if let accounts = entry.accounts { details.append(String(localized: "\(accounts) acc.")) }
            return RankingEntry(label: value, value: entry.events ?? 0, detail: details.joined(separator: " · "), monospaced: mono)
        })
    }
}
