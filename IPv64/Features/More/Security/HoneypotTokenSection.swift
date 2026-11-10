import SwiftUI
import IPv64

/// "Blocklist token" (spec 04 §10.5): shown only after confirmation, masked, hidden again on background / leave.
struct HoneypotTokenSection: View {
    @Environment(Session.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    @State private var token: HoneypotListToken?
    @State private var isBusy = false
    @State private var generation = 0
    @State private var confirm: ConfirmRequest?
    @State private var error: ErrorText?

    var body: some View {
        Section("Blocklist token") {
            if let token {
                HStack {
                    Text("List token").font(.subheadline.weight(.semibold))
                    Spacer()
                    if token.live { StatusChip("Live", color: .ipv64Green) } else { StatusChip("Daily list", color: .ipv64Orange) }
                }
                InfoRow("Token", value: token.token, copyable: true, sensitive: true, monospaced: true)
                InfoRow("List URL", value: SecurityLogic.listURL(base: token.base), copyable: true, sensitive: true, monospaced: true)
                if !token.live {
                    Text("Live access is not available for your account right now. The list URL serves the daily state.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button("Hide", systemImage: "eye.slash", action: hide)
            } else {
                Text("Your personal token gives access to the live v64 blocklist.")
                Button("Show list token", systemImage: "key") { askShow() }.disabled(isBusy)
            }
        }
        .confirmDialog($confirm)
        .errorAlert($error)
        .overlay { if isBusy { LoadingView("Loading token...") } }
        .onChange(of: scenePhase) { if scenePhase != .active { hide() } }
        .onDisappear(perform: hide)
    }

    private func hide() {
        generation += 1
        token = nil
        isBusy = false
    }

    private func askShow() {
        confirm = ConfirmRequest(
            title: String(localized: "Show list token?"),
            message: String(localized: "This creates your personal token if you do not have one yet. Keep it secret: anyone with the token can fetch your live blocklist."),
            confirmLabel: String(localized: "Show token")
        ) { load() }
    }

    private func load() {
        generation += 1
        let mine = generation
        isBusy = true
        Task {
            defer { if mine == generation { isBusy = false } }
            do {
                let result = try await ipv64Retrying { try await session.api.honeypot.listToken() }
                if mine == generation { token = result }
            } catch is CancellationError {
            } catch {
                if mine == generation { self.error = ErrorText(error) }
            }
        }
    }
}
