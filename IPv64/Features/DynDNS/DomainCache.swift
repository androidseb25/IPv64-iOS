import SwiftUI
import IPv64

/// In-memory domain detail cache (5 min TTL, cleared on account switch). Shared by list, detail, settings, record edit.
@MainActor
enum DomainCache {
    private static var entries: [String: (detail: DomainDetail, at: Date)] = [:]
    private static var revision = 0
    private static let ttl: TimeInterval = 300

    static func get(_ name: String, revision current: Int) -> DomainDetail? {
        reset(for: current)
        guard let entry = entries[name], Date().timeIntervalSince(entry.at) < ttl else { return nil }
        return entry.detail
    }

    static func put(_ detail: DomainDetail, revision current: Int) {
        reset(for: current)
        if let name = detail.name { entries[name] = (detail, Date()) }
    }

    static func invalidate(_ name: String) { entries[name] = nil }

    private static func reset(for current: Int) {
        guard current != revision else { return }
        revision = current
        entries = [:]
    }
}

/// Serialises the lazy per-row detail requests of the list: one at a time, at most one per second.
@MainActor
final class DetailRequestGate {
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var last = Date.distantPast

    func run<T>(_ work: () async -> T) async -> T {
        if busy { await withCheckedContinuation { waiters.append($0) } }
        busy = true
        defer {
            busy = false
            if !waiters.isEmpty { waiters.removeFirst().resume() }
        }
        let wait = last.addingTimeInterval(1).timeIntervalSinceNow
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
        let result = await work()
        last = Date()
        return result
    }
}

extension DynDNSLogic.IpStatus {
    var label: LocalizedStringKey {
        switch self {
        case .checking: "Checking"
        case .noIp: "No IP"
        case .unknown: "IP unknown"
        case .differs: "IP differs"
        case .matches: "IP matches"
        }
    }

    var color: Color {
        switch self {
        case .differs: .ipv64Red
        case .matches: .ipv64Green
        default: .ipv64Gray
        }
    }
}

/// A form sheet: Cancel leading, confirm trailing, locked while busy.
struct DynDNSSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    var subtitle: String?
    var confirmLabel: LocalizedStringKey?
    var confirmEnabled = true
    var isBusy = false
    var onConfirm: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            Form {
                if let subtitle { Section { Text(verbatim: subtitle).foregroundStyle(.secondary) } }
                content
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if confirmLabel == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") { dismiss() }
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark") { dismiss() }.disabled(isBusy)
                    }
                }
                if let onConfirm, let confirmLabel {
                    ToolbarItem(placement: .confirmationAction) {
                        if isBusy {
                            ProgressView()
                        } else {
                            Button(confirmLabel, systemImage: "checkmark", action: onConfirm).disabled(!confirmEnabled)
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isBusy)
    }
}
