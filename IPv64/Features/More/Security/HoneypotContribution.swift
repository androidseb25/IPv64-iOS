import SwiftUI
import IPv64

/// "Your contribution": own stats, sensors (spec 04 §10.4).
struct HoneypotContribution: View {
    let stats: HoneypotStats
    let sensors: [HoneypotSensor]

    var body: some View {
        Section {
            HStack {
                Text("Your contribution").font(.headline)
                Spacer()
                if stats.contributor == true {
                    StatusChip("Contributor", color: .ipv64Green)
                } else {
                    StatusChip("Not contributing", color: .ipv64Gray)
                }
            }
            StatTiles {
                StatTile(value: "\(stats.sensorsOnline ?? 0) / \(stats.sensors ?? 0)", label: "Sensors online")
                StatTile(value: Formatters.count(stats.events24h ?? 0), label: "Events (24 h)")
                StatTile(value: Formatters.count(stats.events7d ?? 0), label: "Events (7 d)")
                StatTile(value: Formatters.count(stats.sources24h ?? 0), label: "Sources (24 h)")
                StatTile(value: Formatters.count(stats.sources7d ?? 0), label: "Sources (7 d)")
            }
        } footer: {
            if let last = stats.lastReport { Text("Last report \(Formatters.relative(last))") }
        }
        let days = (stats.timeline ?? []).compactMap { d in d.day.map { DayValue(day: $0, value: d.events ?? 0) } }
        if !days.isEmpty {
            Section("Events per day (7 days)") { DayBarChart(days: days, color: .ipv64Orange) }
        }
        Section("Sensors") {
            if sensors.isEmpty {
                EmptyStateView("You have no sensors yet. Sensors are provided by the Node64 honeypot module.")
            }
            ForEach(sensors) { sensor in
                ListRow(verbatim: SecurityLogic.sensorTitle(sensor.id), subtitle: subtitle(sensor), subtitleLineLimit: 5) {
                    if sensor.disabled == true {
                        StatusChip("Disabled", color: .ipv64Gray)
                    } else if sensor.online == true {
                        StatusChip("Online", color: .ipv64Green)
                    } else {
                        StatusChip("Offline", color: .ipv64Red)
                    }
                }
            }
        }
    }

    private func subtitle(_ s: HoneypotSensor) -> String {
        var lines: [String] = []
        let profile = [s.profile, s.mode, s.version.map { "v\($0)" }].compactMap { $0?.nonBlank }.joined(separator: " · ")
        if !profile.isEmpty { lines.append(String(localized: "Profile: \(profile)")) }
        if let last = Formatters.realOrNil(s.lastSeen) { lines.append(String(localized: "Last report \(Formatters.relative(last))")) }
        lines.append(String(localized: "Reports: \(s.reports ?? 0)"))
        lines.append(String(localized: "Events (24 h / 7 d): \(s.events24h ?? 0) / \(s.events7d ?? 0)"))
        lines.append(String(localized: "Sources (24 h / 7 d): \(s.sources24h ?? 0) / \(s.sources7d ?? 0)"))
        return lines.joined(separator: "\n")
    }
}
