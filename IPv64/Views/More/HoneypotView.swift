import SwiftUI
import IPv64

/// "Honeypot": network numbers, own contribution, sensors and the list token (no live feed).
struct HoneypotView: View {
    @Environment(Session.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    @State private var cloud: ThreatStats?
    @State private var nodes: [HC2Node]?
    @State private var stats: HoneypotStats?
    @State private var sensors: [HoneypotSensor] = []
    @State private var loaded = false
    @State private var error: ErrorText?

    @State private var token: HoneypotListToken?
    @State private var tokenRevealed = false
    @State private var tokenBusy = false
    @State private var tokenGeneration = 0
    @State private var askToken = false

    var body: some View {
        List {
            if loaded {
                if let cloud { HoneypotNetworkSections(stats: cloud) }
                if let nodes { HoneypotNodeShare(nodes: nodes) }
                if let stats { HoneypotContributionSections(stats: stats, sensors: sensors) }
                tokenSection
            }
        }
        .overlay { if !loaded && error == nil { ProgressView() } }
        .navigationTitle("Honeypot")
        .navigationBarTitleDisplayMode(.inline)
        .moreGradient()
        .moreToolbarSpinner(tokenBusy)
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: scenePhase) { if scenePhase != .active { hideToken() } }
        .onDisappear(perform: hideToken)
        .alert("Show list token?", isPresented: $askToken) {
            Button("Show token") { loadToken() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This creates your personal token if you do not have one yet. Keep it secret: anyone with the token can fetch your live blocklist.")
        }
        .errorAlert($error)
    }

    // MARK: Token

    private var tokenSection: some View {
        Section("Blocklist token") {
            if let token {
                HStack {
                    Text("List token").font(.subheadline.weight(.semibold))
                    Spacer()
                    if token.live { MoreTag(String(localized: "Live"), .green) } else { MoreTag(String(localized: "Daily list"), .orange) }
                }
                secretRow("Token", token.token)
                if let url = MoreLogic.listURL(base: token.base) { secretRow("List URL", url) }
                if !token.live {
                    Text("Live access is not available for your account right now. The list URL serves the daily state.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button("Hide", systemImage: "eye.slash", action: hideToken)
            } else {
                Text("Your personal token gives access to the live v64 blocklist.")
                Button("Show list token", systemImage: "key") { askToken = true }.disabled(tokenBusy)
            }
        }
    }

    /// Masked until the eye is tapped; copying is always sensitive.
    private func secretRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(verbatim: tokenRevealed ? value : String(repeating: "•", count: min(value.count, 24)))
                    .font(.body.monospaced()).lineLimit(3)
                Spacer(minLength: 8)
                Button(tokenRevealed ? "Hide" : "Show", systemImage: tokenRevealed ? "eye.slash" : "eye") { tokenRevealed.toggle() }
                Button("Copy", systemImage: "document.on.document") { Clipboard.copy(value, sensitive: true) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
    }

    private func hideToken() {
        tokenGeneration += 1
        token = nil
        tokenRevealed = false
        tokenBusy = false
    }

    private func loadToken() {
        tokenGeneration += 1
        let mine = tokenGeneration
        tokenBusy = true
        Task {
            defer { if mine == tokenGeneration { tokenBusy = false } }
            do {
                let result = try await ipv64Retrying { try await session.api.honeypot.listToken() }
                if mine == tokenGeneration { token = result }
            } catch is CancellationError {
            } catch {
                if mine == tokenGeneration { self.error = ErrorText(error) }
            }
        }
    }

    // MARK: Load

    private func load() async {
        do {
            let own = try await ipv64Retrying { try await session.api.honeypot.stats() }
            let list = try await ipv64Retrying { try await session.api.honeypot.sensors() }
            stats = own
            sensors = list
            cloud = try? await session.api.threat.stats()
            nodes = try? await session.api.hc2.nodes.list()
            loaded = true
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }
}
