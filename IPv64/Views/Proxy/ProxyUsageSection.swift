import SwiftUI
import IPv64

/// CDN64 usage in the style of `CdnUsageSection`: the node's quota is preferred, else the account's usage.
/// Limit 0 or missing = unlimited.
struct ProxyUsageSection: View {
    let usage: Me.Usage?
    let quota: Node64.CDNOnlineQuota?

    var body: some View {
        if let quota {
            Section("Usage") {
                let domains = quota.domains
                let domainLimit = ProxyLogic.limit(domains?.limit)
                UsageBlock(title: "CDN domains", value: Text("\(domains?.used ?? 0)"),
                           limit: domainLimit.map { String(localized: "of \($0)") } ?? String(localized: "unlimited"),
                           fraction: CdnLogic.fraction(used: Double(domains?.used ?? 0), limit: domainLimit),
                           hint: ProxyLogic.limit(domains?.oldCDN).map { String(localized: "\($0) in the old CDN") })
                let used = quota.trafficMB?.used ?? 0
                let trafficLimit = ProxyLogic.limit(quota.trafficMB?.limit)
                UsageBlock(title: "Traffic this month", value: Text(verbatim: CdnLogic.megabytes(used)),
                           limit: trafficLimit.map { String(localized: "of \(CdnLogic.megabytes(Double($0)))") } ?? String(localized: "unlimited"),
                           fraction: CdnLogic.fraction(used: used, limit: trafficLimit),
                           hint: quota.bandwidthMbit.map {
                               $0 > 0 ? String(localized: "Bandwidth: \($0) Mbit/s") : String(localized: "Bandwidth: unlimited")
                           })
            }
        } else {
            CdnUsageSection(usage: usage)
        }
    }
}
