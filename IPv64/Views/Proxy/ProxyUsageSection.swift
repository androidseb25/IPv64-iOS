import SwiftUI
import IPv64

/// CDN64 usage in the style of Health / Screen Time, domains and traffic side by side. The node's quota is
/// preferred, else the account's usage. Limit 0 or missing = unlimited.
struct ProxyUsageSection: View {
    let usage: Me.Usage?
    let quota: Node64.CDNOnlineQuota?

    private var blocks: (domains: UsageBlock, traffic: UsageBlock)? {
        if let quota {
            let domains = quota.domains
            let domainLimit = ProxyLogic.limit(domains?.limit)
            let used = quota.trafficMB?.used ?? 0
            let trafficLimit = ProxyLogic.limit(quota.trafficMB?.limit)
            return (
                UsageBlock(title: "CDN domains", value: "\(domains?.used ?? 0)",
                           limit: domainLimit.map { String(localized: "of \($0)") } ?? String(localized: "unlimited"),
                           fraction: ProxyLogic.fraction(used: Double(domains?.used ?? 0), limit: domainLimit)),
                UsageBlock(title: "Traffic this month", value: ProxyLogic.megabytes(used),
                           limit: trafficLimit.map { String(localized: "of \(ProxyLogic.megabytes(Double($0)))") } ?? String(localized: "unlimited"),
                           fraction: ProxyLogic.fraction(used: used, limit: trafficLimit),
                           hint: quota.bandwidthMbit.map {
                               $0 > 0 ? String(localized: "Bandwidth: \($0) Mbit/s") : String(localized: "Bandwidth: unlimited")
                           }))
        }
        guard usage?.cdnDomains != nil || usage?.cdnTrafficGB != nil else { return nil }
        let d = usage?.cdnDomains, t = usage?.cdnTrafficGB
        let domainLimit = ProxyLogic.limit(d?.limit)
        let trafficLimit = ProxyLogic.limit(t?.limit)
        return (
            UsageBlock(title: "CDN domains", value: "\(Int(d?.used ?? 0))",
                       limit: domainLimit.map { String(localized: "of \($0)") } ?? String(localized: "unlimited"),
                       fraction: ProxyLogic.fraction(used: d?.used, limit: domainLimit)),
            UsageBlock(title: "Traffic this month", value: ProxyLogic.megabytes((t?.used ?? 0) * 1024),
                       limit: trafficLimit.map { String(localized: "of \(ProxyLogic.megabytes(Double($0) * 1024))") } ?? String(localized: "unlimited"),
                       fraction: ProxyLogic.fraction(used: t?.used, limit: trafficLimit)))
    }

    var body: some View {
        if let blocks {
            Section("Usage") {
                HStack(alignment: .top, spacing: 16) {
                    blocks.domains
                    blocks.traffic
                }
                .padding(.vertical, 4)
            }
        }
    }
}

/// One number block of a usage section: title, number, limit text, progress bar and optional small hint.
struct UsageBlock: View {
    let title: LocalizedStringKey
    let value: String
    let limit: String
    let fraction: Double?
    var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            Text(verbatim: value)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(verbatim: limit).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            if let fraction {
                ProgressView(value: fraction).tint(fraction >= 1 ? .red : fraction >= 0.8 ? .orange : .accentColor)
            }
            if let hint { Text(verbatim: hint).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
