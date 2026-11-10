import SwiftUI
import IPv64

/// Stats card (spec 03 §2): node quota preferred, else account usage; hidden without data.
struct ProxyStatsSection: View {
    let usage: Me.Usage?
    let quota: Node64.CDNOnlineQuota?

    private var stats: ProxyLogic.Stats? {
        if let quota {
            return ProxyLogic.quotaStats(
                domainsUsed: quota.domains?.used, domainsLimit: quota.domains?.limit, oldCDN: quota.domains?.oldCDN,
                trafficUsedMB: quota.trafficMB?.used, trafficLimitMB: quota.trafficMB?.limit,
                bandwidthMbit: quota.bandwidthMbit)
        }
        guard usage?.cdnDomains != nil || usage?.cdnTrafficGB != nil else { return nil }
        return ProxyLogic.usageStats(
            domainsUsed: usage?.cdnDomains?.used, domainsLimit: usage?.cdnDomains?.limit,
            trafficUsedGB: usage?.cdnTrafficGB?.used, trafficLimitGB: usage?.cdnTrafficGB?.limit)
    }

    var body: some View {
        if let stats {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    StatBlock(title: "CDN domains", value: stats.domains, fraction: stats.domainFraction, hint: stats.domainHint)
                    StatBlock(title: "CDN traffic this month", value: stats.traffic, fraction: stats.trafficFraction, hint: stats.trafficHint)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct StatBlock: View {
    let title: LocalizedStringKey
    let value: String
    let fraction: Double?
    let hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: value).font(.headline)
            if let fraction { ProgressView(value: min(max(fraction, 0), 1)) }
            if let hint { Text(verbatim: hint).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
