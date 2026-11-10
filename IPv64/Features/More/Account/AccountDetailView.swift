import SwiftUI

/// "Users" (spec 01 §3.6): tap switches, long press edits, trash removes from this app.
struct AccountDetailView: View {
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    @State private var confirm: ConfirmRequest?
    @State private var message: String?

    var body: some View {
        List {
            Section {
                ForEach(session.accounts.accounts) { account in
                    row(account)
                }
            } footer: {
                Text("Tap to switch accounts. For editing the name and information field, make a long press. The delete icon only removes an account from this app.")
            }
        }
        .navigationTitle("Users")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add account", systemImage: "person.badge.plus") { router.push(.addAccount) }
            }
        }
        .confirmDialog($confirm)
        .appBottomBar { SnackbarText(message: $message) }
        .onAppear {
            if let flash = router.flash {
                router.flash = nil
                message = flash
            }
        }
    }

    private func row(_ account: Account) -> some View {
        let active = session.accounts.isActive(account)
        return Button {
            session.activate(account)
            router.pop()
        } label: {
            ListRow(verbatim: account.username, subtitle: account.displayInformation,
                    systemImage: "person.crop.circle", subtitleLineLimit: 1) {
                if active { StatusChip("Active", color: .ipv64Green) }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button("Remove", systemImage: "trash", role: .destructive) { askRemove(account) }
            Button("Edit User", systemImage: "pencil") { router.push(.accountEdit(accountId: account.id)) }
                .tint(.ipv64Blue)
        }
        .contextMenu {
            Button("Edit User", systemImage: "pencil") { router.push(.accountEdit(accountId: account.id)) }
            Button("Remove", systemImage: "trash", role: .destructive) { askRemove(account) }
        }
    }

    private func askRemove(_ account: Account) {
        confirm = ConfirmRequest(
            title: String(localized: "Remove account from this app?"),
            message: AccountRemovalText.confirm(account, accounts: session.accounts.accounts,
                                                activeKey: session.accounts.activeKey),
            confirmLabel: String(localized: "Remove"),
            destructive: true
        ) {
            let result = session.removeAccount(id: account.id)
            message = AccountRemovalText.message(result, name: account.username)
        }
    }
}

/// Android Snackbar: a short message at the bottom that hides itself after 4 s.
struct SnackbarText: View {
    @Binding var message: String?

    var body: some View {
        if let message {
            Text(verbatim: message)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appGlass(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation { self.message = nil }
                }
        }
    }
}
