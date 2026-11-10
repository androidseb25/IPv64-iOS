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
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(role == .destructive ? Color.ipv64Red : Color.primary)
                    .frame(width: 40, height: 40)
                    .background(role == .destructive ? tint.opacity(0.15) : Color(.secondarySystemFill), in: Circle())
                Text(label)
                    .font(.caption)
                    .foregroundStyle(role == .destructive ? Color.ipv64Red : Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 88, maxHeight: .infinity)
        }
        .buttonStyle(AppTileButtonStyle())
        .opacity(isEnabled ? 1 : 0.38)
    }
}

struct ActionTileRow<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        HStack(spacing: 8) { content }
            .fixedSize(horizontal: false, vertical: true)
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
