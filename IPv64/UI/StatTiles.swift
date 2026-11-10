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
        .appCard()
        .accessibilityElement(children: .combine)
    }
}

/// Equal-size tiles in an adaptive grid (as many columns as fit at `minWidth`).
struct StatTiles<Content: View>: View {
    private let spacing: CGFloat
    private let minWidth: CGFloat
    private let content: Content

    init(spacing: CGFloat = 8, minWidth: CGFloat = 100, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.minWidth = minWidth
        self.content = content()
    }

    var body: some View {
        AppGlassGroup(spacing: spacing) {
            EqualTilesLayout(spacing: spacing, minWidth: minWidth) { content }
        }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
    }
}

/// Equal-size cells, as many columns as fit at `minWidth` (all rows as tall as the tallest cell).
struct EqualTilesLayout: Layout {
    let spacing: CGFloat
    let minWidth: CGFloat

    private func columns(_ width: CGFloat, count: Int) -> Int {
        max(1, min(count, Int((width + spacing) / (minWidth + spacing))))
    }

    private func metrics(_ proposal: ProposedViewSize, _ subviews: Subviews) -> (cols: Int, cell: CGSize) {
        let width = proposal.width ?? CGFloat(subviews.count) * (minWidth + spacing)
        let cols = columns(width, count: subviews.count)
        let cellWidth = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
        let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height }.max() ?? 0
        return (cols, CGSize(width: cellWidth, height: height))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let (cols, cell) = metrics(proposal, subviews)
        let rows = (subviews.count + cols - 1) / cols
        return CGSize(width: proposal.width ?? CGFloat(cols) * cell.width + CGFloat(cols - 1) * spacing,
                      height: CGFloat(rows) * cell.height + CGFloat(rows - 1) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let (cols, cell) = metrics(ProposedViewSize(width: bounds.width, height: nil), subviews)
        for (index, subview) in subviews.enumerated() {
            let origin = CGPoint(x: bounds.minX + CGFloat(index % cols) * (cell.width + spacing),
                                 y: bounds.minY + CGFloat(index / cols) * (cell.height + spacing))
            subview.place(at: origin, proposal: ProposedViewSize(cell))
        }
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
