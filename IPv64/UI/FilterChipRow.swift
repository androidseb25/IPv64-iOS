import SwiftUI

struct FilterChipRow<Option: Hashable, Trailing: View>: View {
    private let options: [Option]
    private let selected: Option?
    private let label: (Option) -> Text
    private let onSelect: (Option) -> Void
    private let trailing: Trailing

    init(options: [Option], selected: Option?, label: @escaping (Option) -> Text,
         onSelect: @escaping (Option) -> Void, @ViewBuilder trailing: () -> Trailing) {
        self.options = options
        self.selected = selected
        self.label = label
        self.onSelect = onSelect
        self.trailing = trailing()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            AppGlassGroup {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = option == selected
                        Button { onSelect(option) } label: {
                            HStack(spacing: 4) {
                                if isSelected { Image(systemName: "checkmark").font(.footnote.weight(.semibold)) }
                                label(option).font(.subheadline)
                            }
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .appChip(selected: isSelected)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                    if Trailing.self != EmptyView.self {
                        Divider().frame(height: 24)
                        trailing
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

extension FilterChipRow where Trailing == EmptyView {
    init(options: [Option], selected: Option?, label: @escaping (Option) -> Text,
         onSelect: @escaping (Option) -> Void) {
        self.init(options: options, selected: selected, label: label, onSelect: onSelect) { EmptyView() }
    }
}

#Preview {
    @Previewable @State var sel: String? = "All"
    FilterChipRow(options: ["All", "Own", "DynDNS"], selected: sel, label: { Text(verbatim: $0) }) { sel = $0 }
}
