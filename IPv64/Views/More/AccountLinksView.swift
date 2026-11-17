import SwiftUI
import IPv64

/// "Account links" (read-only).
struct AccountLinksView: View {
    @Environment(Session.self) private var session
    @Environment(\.openURL) private var openURL

    @State private var links: AccountLinks?
    @State private var error: ErrorText?

    var body: some View {
        List {
            if let links {
                Section {
                    Text("Account links let another IPv64 account manage yours, or you manage theirs. Links are managed at ipv64.net.")
                    Button("Manage at ipv64.net", systemImage: "arrow.up.right.square") {
                        if let url = URL(string: "https://ipv64.net/account") { openURL(url) }
                    }
                }
                group("Can manage your account", links.sharedWith)
                group("Accounts you manage", links.managed)
            }
        }
        .overlay { if links == nil && error == nil { ProgressView() } }
        .navigationTitle("Account links")
        .navigationBarTitleDisplayMode(.inline)
        .moreGradient()
        .refreshable { await load() }
        .task { await load() }
        .errorAlert($error)
    }

    @ViewBuilder private func group(_ title: LocalizedStringKey, _ items: [AccountLink]?) -> some View {
        if let items, !items.isEmpty {
            Section(title) {
                ForEach(items) { link in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(verbatim: link.email?.nonBlank ?? String(localized: "Unknown account")).font(.headline)
                            Spacer(minLength: 8)
                            if link.status == .active { MoreTag(String(localized: "Active"), .green) }
                            else if link.status == .pending { MoreTag(String(localized: "Pending"), .orange) }
                        }
                        Text(verbatim: subtitle(link)).font(.footnote).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func subtitle(_ link: AccountLink) -> String {
        var lines: [String] = []
        if let created = HcFormat.time(link.createdAt) { lines.append(String(localized: "Created \(created)")) }
        let used = HcFormat.real(link.lastUsedAt).map { $0.formatted(.relative(presentation: .named)) } ?? "–"
        lines.append(String(localized: "Last used: \(used)"))
        return lines.joined(separator: "\n")
    }

    private func load() async {
        do {
            links = try await session.api.account.links()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }
}
