import SwiftUI

/// Welcome → Login without an account, else the tab shell; the lock screen covers everything (spec 01 §2, §3b).
struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAuthenticating = false

    var body: some View {
        @Bindable var accounts = session.accounts
        Group {
            if session.isLoggedIn {
                MainTabView()
            } else {
                NavigationStack { WelcomeView() }
            }
        }
        .tint(.orange)
        .accessibilityHidden(session.isLocked)
        .lockWindow(isPresented: session.isLocked) {
            LockView { Task { await authenticate() } }
        }
        // Lock on background only: `.inactive` also fires for the Face ID sheet and Control Center.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background where session.lockscreenEnabled: session.isLocked = true
            case .active where session.isLocked: Task { await authenticate() }
            default: break
            }
        }
        .task { if session.isLocked { await authenticate() } }
        .alert("Secure storage unavailable", isPresented: Binding(
            get: { accounts.storageError != nil }, set: { if !$0 { accounts.storageError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: accounts.storageError ?? "")
        }
    }

    private func authenticate() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await Biometrics.authenticate() { session.isLocked = false }
    }
}
