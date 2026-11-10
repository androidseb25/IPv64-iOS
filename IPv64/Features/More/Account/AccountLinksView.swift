import SwiftUI
import IPv64

/// "Account links" (spec 04 §9, read-only).
struct AccountLinksView: View {
    @Environment(Session.self) private var session
    @Environment(\.openURL) private var openURL

    @State private var links: AccountLinks?
    @State private var isLoading = false
    @State private var error: ErrorText?

    var body: some View {
        List {
            Section {
                Text("Account links let another IPv64 account manage yours, or you manage theirs. Links are managed at ipv64.net.")
                Button("Manage at ipv64.net", systemImage: "arrow.up.right.square") {
                    if let url = URL(string: "https://ipv64.net/account") { openURL(url) }
                }
            }
            if let links {
                group("Can manage your account", links.sharedWith, empty: "Nobody else can manage your account.")
                group("Accounts you manage", links.managed, empty: "You don't manage any other account.")
            }
        }
        .navigationTitle("Account links")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task(id: session.accountRevision) { await load() }
        .loadingOverlay(isLoading && links == nil)
        .errorAlert($error) { Task { await load() } }
    }

    private func group(_ title: LocalizedStringKey, _ items: [AccountLink]?, empty: LocalizedStringKey) -> some View {
        Section(title) {
            if let items, !items.isEmpty {
                ForEach(items) { link in
                    ListRow(verbatim: link.email?.nonBlank ?? String(localized: "Unknown account"),
                            subtitle: subtitle(link), subtitleLineLimit: 3) { chip(link.status) }
                }
            } else {
                Text(empty).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func chip(_ status: AccountLinkStatus?) -> some View {
        if status == .active {
            StatusChip("Active", color: .ipv64Green)
        } else if status == .pending {
            StatusChip("Pending", color: .ipv64Orange)
        }
    }

    private func subtitle(_ link: AccountLink) -> String {
        var lines: [String] = []
        if let created = Formatters.realOrNil(link.createdAt) {
            lines.append(String(localized: "Created \(Formatters.germanTime(created))"))
        }
        lines.append(String(localized: "Last used: \(Formatters.ago(link.lastUsedAt) ?? "–")"))
        return lines.joined(separator: "\n")
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            links = try await session.api.account.links()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }
}
