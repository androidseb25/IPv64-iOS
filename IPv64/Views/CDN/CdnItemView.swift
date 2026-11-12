import SwiftUI
import IPv64

/// CDN domain row: name, server and traffic, tag for the state.
struct CdnItemView: View {
    let domain: CDNDomain

    private var secondary: String {
        let server = domain.server?.name?.nonBlank.map { String(localized: "Server \($0)") + " · " } ?? ""
        let traffic = domain.trafficMB.map {
            String(localized: "in \(CdnLogic.megabytes($0.incoming ?? 0)) · out \(CdnLogic.megabytes($0.outgoing ?? 0))")
        } ?? "–"
        return server + traffic
    }

    private var tag: (text: LocalizedStringKey, color: Color) {
        if domain.isBusy { ("Working", .orange) }
        else if domain.active == true { ("Active", .green) }
        else { ("Inactive", .gray) }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(domain.displayName).font(.headline).lineLimit(1)
                Text(verbatim: secondary).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(tag.text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tag.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tag.color.opacity(0.15), in: Capsule())
                .fixedSize()
        }
    }
}
