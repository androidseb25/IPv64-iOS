import SwiftUI

struct ActionTile: View {
    @Environment(\.isEnabled) private var isEnabled

    private let label: LocalizedStringKey
    private let systemImage: String
    private let role: ButtonRole?
    private let action: () -> Void

    init(_ label: LocalizedStringKey, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    private var tint: Color { role == .destructive ? .ipv64Red : .accentColor }

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(height: 28)
                Text(label)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(role == .destructive ? Color.ipv64Red : Color.accentColor)
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .appTileButtonStyle()
        .opacity(isEnabled ? 1 : 0.38)
    }
}

/// Equal-width action buttons in one row; wraps into equal tiles when the captions don't fit
/// (narrow width, large Dynamic Type). In a `List` it forms its own transparent row.
struct ActionTileRow<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        AppGlassGroup {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { content }
                    .fixedSize(horizontal: false, vertical: true)
                EqualTilesLayout(spacing: 8, minWidth: 120) { content }
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowBackground(Color.clear)
    }
}

#Preview {
    ActionTileRow {
        ActionTile("Edit", systemImage: "pencil") {}
        ActionTile("Delete everything now", systemImage: "trash", role: .destructive) {}
        ActionTile("Disabled", systemImage: "lock") {}.disabled(true)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
