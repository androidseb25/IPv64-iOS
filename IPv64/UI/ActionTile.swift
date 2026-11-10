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
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(AppTileButtonStyle())
        .opacity(isEnabled ? 1 : 0.38)
    }
}

/// Equal-width action buttons in one row. In a `List` it forms its own transparent row.
struct ActionTileRow<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        AppGlassGroup {
            HStack(spacing: 8) { content }
                .fixedSize(horizontal: false, vertical: true)
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
