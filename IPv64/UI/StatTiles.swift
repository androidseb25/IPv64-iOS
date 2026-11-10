import SwiftUI

struct StatTile: View {
    private let value: String
    private let label: LocalizedStringKey
    private let valueColor: Color?

    init(value: String, label: LocalizedStringKey, valueColor: Color? = nil) {
        self.value = value
        self.label = label
        self.valueColor = valueColor
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.headline)
                .foregroundStyle(valueColor ?? .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Equal width and equal height tiles in one row.
struct StatTiles<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HStack(spacing: spacing) { content }
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    StatTiles {
        StatTile(value: "12", label: "Domains")
        StatTile(value: "Very long value text here", label: "Records", valueColor: .ipv64Green)
        StatTile(value: "3", label: "Checks")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
