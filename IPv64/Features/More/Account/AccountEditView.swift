import SwiftUI

/// "Edit User" (spec 01 §3.5): local label and information of an account, or remove it from this app.
struct AccountEditView: View {
    let accountId: UUID

    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    @State private var username = ""
    @State private var information = ""
    @State private var loaded = false
    @State private var showEmptyField = false
    @State private var confirm: ConfirmRequest?

    private var account: Account? { session.accounts.account(id: accountId) }

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $username)
                TextField("Information", text: $information)
            } header: {
                Text("Account")
            } footer: {
                Text("Removes this entry from this device only. The account and its API key stay valid on ipv64.net.")
            }
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Edit User")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Remove account from this app", systemImage: "trash", role: .destructive, action: askRemove)
                    .disabled(account == nil)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark", action: save)
                    .disabled(account == nil)
            }
        }
        .onAppear {
            guard !loaded, let account else { return }
            loaded = true
            username = account.username
            information = account.information
        }
        .alert("Empty field", isPresented: $showEmptyField) {
            Button("Retry", role: .cancel) {}
        } message: {
            Text("Please fill the Username field!")
        }
        .confirmDialog($confirm)
    }

    private func save() {
        guard var account else { return }
        guard !username.isEmpty else {
            showEmptyField = true
            return
        }
        account.username = username
        account.information = information
        session.accounts.update(account)
        router.pop()
    }

    private func askRemove() {
        guard let account else { return }
        confirm = ConfirmRequest(
            title: String(localized: "Remove account from this app?"),
            message: AccountRemovalText.confirm(account, accounts: session.accounts.accounts,
                                                activeKey: session.accounts.activeKey),
            confirmLabel: String(localized: "Remove"),
            destructive: true
        ) {
            let result = session.removeAccount(id: account.id)
            router.flash = AccountRemovalText.message(result, name: account.username)
            router.pop()
        }
    }
}
