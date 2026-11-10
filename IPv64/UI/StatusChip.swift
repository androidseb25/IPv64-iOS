import SwiftUI

enum Hc2StateUi: CaseIterable {
    case up, down, degraded, flapping, paused, pending, unknown

    var label: LocalizedStringKey {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .degraded: "Degraded"
        case .flapping: "Flapping"
        case .paused: "Paused"
        case .pending: "Pending"
        case .unknown: "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .up: .ipv64Green
        case .down: .ipv64Red
        case .degraded, .flapping: .ipv64Orange
        case .paused: .ipv64Teal
        case .pending, .unknown: .ipv64Gray
        }
    }

    var systemImage: String {
        switch self {
        case .up: "heart.circle"
        case .down, .degraded: "exclamationmark.triangle"
        case .flapping: "arrow.up.arrow.down.circle"
        case .paused: "pause.circle"
        case .pending: "clock"
        case .unknown: "questionmark.square"
        }
    }

    nonisolated static func from(_ state: String?) -> Hc2StateUi {
        switch state?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "up": .up
        case "down": .down
        case "degraded": .degraded
        case "flapping": .flapping
        case "paused": .paused
        case "pending": .pending
        default: .unknown
        }
    }

    nonisolated static func from(_ state: String?, paused: Bool?) -> Hc2StateUi {
        paused == true ? .paused : from(state)
    }
}

struct StatusChip: View {
    private let text: Text
    private let color: Color

    init(_ text: LocalizedStringKey, color: Color) {
        self.text = Text(text)
        self.color = color
    }

    init(verbatim: String, color: Color) {
        self.text = Text(verbatim: verbatim)
        self.color = color
    }

    init(state: Hc2StateUi) {
        self.init(state.label, color: state.color)
    }

    var body: some View {
        // 2.0 look: coloured dot and text instead of a Material-style capsule.
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            text.font(.footnote).lineLimit(1).fixedSize().foregroundStyle(color)
        }
    }
}

#Preview {
    HStack {
        ForEach(Hc2StateUi.allCases, id: \.self) { StatusChip(state: $0) }
    }
    StatusChip(verbatim: "Custom", color: .ipv64Blue)
}
