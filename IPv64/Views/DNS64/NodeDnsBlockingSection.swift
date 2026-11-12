import SwiftUI
import IPv64

/// Blocking card: state, countdown, pause durations, resume. An unreachable node shows only the error.
struct NodeDnsBlockingSection: View {
    let blocking: DnsSec<Node64.DNS64Blocking?>
    let dns: Node64.DNS64
    let actions: DnsActions
    let onChange: (Node64.DNS64Blocking) -> Void
    let onExpired: () -> Void

    @State private var now = Date()
    /// End of a pause started in this session (kept until resumed).
    @State private var localEnd: Date?
    @State private var pending: Choice?

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

    private var current: Node64.DNS64Blocking? { (try? blocking.get()) ?? nil }
    private var paused: Bool { current?.paused == true }

    private var end: Date? {
        guard paused, current?.untilResumed != true else { return nil }
        return HcFormat.real(current?.pausedUntil) ?? localEnd
    }

    var body: some View {
        Section("Blocking") {
            switch blocking {
            case .failure(let failure):
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: failure.text).foregroundStyle(.red)
                    Text("Check the connection under More → Nodes.").font(.subheadline).foregroundStyle(.secondary)
                }
            case .success:
                LabeledContent {
                    ProxyTag(tag: .init(text: paused ? String(localized: "Paused") : String(localized: "Active"),
                                        tone: paused ? .orange : .green))
                } label: {
                    Text(verbatim: dns64BlockingTitle(paused: paused, end: end, now: now))
                }
                if paused {
                    Button("Resume", systemImage: "play.fill") {
                        Task { await actions.run { onChange(try await dns.resume()) } }
                    }
                } else {
                    Menu {
                        ForEach(Self.choices) { choice in
                            Button(choice.label) { pending = choice }
                        }
                    } label: {
                        Label("Pause blocking for", systemImage: "pause.fill")
                    }
                    .alert("Pause blocking?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                           presenting: pending) { choice in
                        Button("Pause") { pause(choice) }
                        Button("Cancel", role: .cancel) {}
                    } message: { choice in
                        Text(message(choice))
                    }
                }
            }
        }
        .task(id: end) { await countdown() }
        .onChange(of: paused) { if !paused { localEnd = nil } }
    }

    private func message(_ choice: Choice) -> String {
        guard choice.minutes > 0 else { return String(localized: "Ads and trackers will not be blocked until you resume it.") }
        let until = dns64Format(.now.addingTimeInterval(Double(choice.minutes) * 60), .hm)
        return String(localized: "Ads and trackers will not be blocked for \(choice.label) (until \(until)).")
    }

    private func pause(_ choice: Choice) {
        localEnd = choice.minutes > 0 ? .now.addingTimeInterval(Double(choice.minutes) * 60) : nil
        Task { await actions.run { onChange(try await dns.pause(minutes: choice.minutes)) } }
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
