import SwiftUI
import IPv64

/// "Honeypot" (spec 04 §10): network numbers, own contribution, sensors, list token.
struct HoneypotView: View {
    @Environment(Session.self) private var session

    @State private var cloud: ThreatStats?
    @State private var nodes: [HC2Node]?
    @State private var stats: HoneypotStats?
    @State private var sensors: [HoneypotSensor] = []
    @State private var loaded = false
    @State private var isLoading = false
    @State private var error: ErrorText?

    var body: some View {
        List {
            if let cloud {
                Section("ipv64.net network") { networkTiles(cloud) }
                ThreatStatsSections(stats: cloud)
            }
            if let nodes { nodeShare(nodes) }
            if loaded, let stats {
                HoneypotContribution(stats: stats, sensors: sensors)
            }
            if loaded { HoneypotTokenSection() }
        }
        .overlay { if !loaded && !isLoading { EmptyStateView("No data.") } }
        .navigationTitle("Honeypot")
        .navigationBarTitleDisplayMode(.inline)
        .privacyProtected()
        .refreshable { await load() }
        .task(id: session.accountRevision) { await load() }
        .loadingOverlay(isLoading && !loaded, text: "Loading...")
        .errorAlert($error) { Task { await load() } }
    }

    private func networkTiles(_ cloud: ThreatStats) -> some View {
        StatTiles {
            StatTile(value: Formatters.count(cloud.sensors?.online ?? 0), label: "Sensors online")
            StatTile(value: Formatters.count(cloud.attacks24h?.events ?? 0), label: "Attacks (24 h)")
            StatTile(value: Formatters.count(cloud.attacks24h?.sources ?? 0), label: "Attacker IPs (24 h)")
            StatTile(value: Formatters.count(cloud.lists?["v64"] ?? 0), label: "Blocklist size")
        }
    }

    private func nodeShare(_ nodes: [HC2Node]) -> some View {
        let share = SecurityLogic.honeypotShare(modules: nodes.map { $0.modules ?? [] })
        return Section("Your nodes") {
            if nodes.isEmpty {
                Text("No nodes linked yet.").foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(share.active) of \(share.total) nodes run the honeypot").font(.subheadline.weight(.semibold))
                    ProgressView(value: share.fraction)
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let own = try await ipv64Retrying { try await session.api.honeypot.stats() }
            let list = try await ipv64Retrying { try await session.api.honeypot.sensors() }
            stats = own
            sensors = list
            cloud = try? await session.api.threat.stats()
            nodes = try? await session.api.hc2.nodes.list()
            loaded = true
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }
}
