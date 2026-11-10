import SwiftUI
import IPv64

/// "Blocking" card (spec 03 §6.3): state, countdown, pause durations, resume.
struct NodeDnsBlockingSection: View {
    let blocking: DnsSec<Node64.DNS64Blocking?>
    let dns: Node64.DNS64
    let actions: DnsActions
    let onChange: (Node64.DNS64Blocking) -> Void
    let onExpired: () -> Void

    @State private var now = Date()
    /// End of a pause started in this session (kept until resumed).
    @State private var localEnd: Date?
    @State private var confirm: ConfirmRequest?

    private struct Choice: Identifiable {
        let minutes: Int
        let label: String
        var id: Int { minutes }
    }

    private static let choices = [
        Choice(minutes: 5, label: String(localized: "5 min")), Choice(minutes: 15, label: String(localized: "15 min")),
        Choice(minutes: 30, label: String(localized: "30 min")), Choice(minutes: 60, label: String(localized: "1 h")),
        Choice(minutes: 0, label: String(localized: "Until resumed")),
    ]

    private var current: Node64.DNS64Blocking? { try? blocking.get() }
    private var paused: Bool { current?.paused == true }

    private var end: Date? {
        guard paused, current?.untilResumed != true else { return nil }
        return Formatters.realOrNil(current?.pausedUntil) ?? localEnd
    }

    var body: some View {
        Section("Blocking") {
            switch blocking {
            case .failure(let failure):
                Text(verbatim: failure.text).foregroundStyle(Color.ipv64Red)
                Text("Check the connection under More → Nodes.").font(.footnote).foregroundStyle(.secondary)
            case .success:
                LabeledContent {
                    if paused { StatusChip("Paused", color: .ipv64Orange) } else { StatusChip("Active", color: .ipv64Green) }
                } label: {
                    Text(verbatim: dns64BlockingTitle(paused: paused, end: end, now: now))
                }
                if paused {
                    Button("Resume", systemImage: "play.fill") { resume() }
                        .disabled(actions.isBusy)
                } else {
                    pauseChoices
                }
            }
        }
        .confirmDialog($confirm)
        .task(id: end) { await countdown() }
        .onChange(of: paused) { if !paused { localEnd = nil } }
    }

    private var pauseChoices: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pause blocking for").font(.footnote).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                ForEach(Self.choices) { choice in
                    Button { ask(choice) } label: { Text(verbatim: choice.label).frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                        .disabled(actions.isBusy)
                }
            }
        }
    }

    private func ask(_ choice: Choice) {
        let until = dns64Format(.now.addingTimeInterval(Double(choice.minutes) * 60), .hm)
        let message = choice.minutes == 0
            ? String(localized: "Ads and trackers will not be blocked until you resume it.")
            : String(localized: "Ads and trackers will not be blocked for \(choice.label) (until \(until)).")
        confirm = ConfirmRequest(title: String(localized: "Pause blocking?"), message: message,
                                 confirmLabel: String(localized: "Pause")) {
            let minutes = choice.minutes
            localEnd = minutes > 0 ? .now.addingTimeInterval(Double(minutes) * 60) : nil
            Task { await actions.run("Updating...") { onChange(try await dns.pause(minutes: minutes)) } }
        }
    }

    private func resume() {
        Task { await actions.run("Updating...") { onChange(try await dns.resume()) } }
    }

    /// Ticks every 30 s (1 s under 2 minutes) while a pause end is known; reloads once on expiry.
    private func countdown() async {
        guard let end else { return }
        while !Task.isCancelled {
            now = .now
            let remaining = end.timeIntervalSince(now)
            if remaining <= 0 { onExpired(); return }
            do { try await Task.sleep(for: dns64CountdownInterval(remaining: remaining)) } catch { return }
        }
    }
}
