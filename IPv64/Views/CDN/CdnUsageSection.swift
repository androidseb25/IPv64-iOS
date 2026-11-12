import SwiftUI
import IPv64

/// Domains and traffic of the month against the plan, in the style of Health / Screen Time.
struct CdnUsageSection: View {
    let usage: Me.Usage?

    var body: some View {
        if usage?.cdnDomains != nil || usage?.cdnTrafficGB != nil {
            Section("Usage") {
                if let q = usage?.cdnDomains {
                    UsageBlock(title: "CDN domains", value: Text("\(Int(q.used ?? 0))"),
                          limit: q.limit.map { String(localized: "of \($0)") } ?? String(localized: "unlimited"),
                          fraction: CdnLogic.fraction(used: q.used, limit: q.limit))
                }
                if let q = usage?.cdnTrafficGB {
                    UsageBlock(title: "Traffic this month", value: Text(verbatim: CdnLogic.gigabytes(q.used ?? 0)),
                          limit: q.limit.map { String(localized: "of \(CdnLogic.gigabytes(Double($0)))") } ?? String(localized: "unlimited"),
                          fraction: CdnLogic.fraction(used: q.used, limit: q.limit))
                }
            }
        }
    }
}

/// One number block of a usage section: title, large value, limit text, progress bar and optional hint.
struct UsageBlock: View {
    let title: LocalizedStringKey
    let value: Text
    let limit: String
    let fraction: Double?
    var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                value.font(.system(.largeTitle, design: .rounded, weight: .semibold))
                Text(verbatim: limit).font(.subheadline).foregroundStyle(.secondary)
            }
            if let fraction {
                ProgressView(value: fraction).tint(fraction >= 1 ? .red : fraction >= 0.8 ? .orange : .accentColor)
            }
            if let hint { Text(verbatim: hint).font(.footnote).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
