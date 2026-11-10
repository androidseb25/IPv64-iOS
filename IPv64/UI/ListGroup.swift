import SwiftUI

struct SectionHeader: View {
    private let text: Text

    init(_ text: LocalizedStringKey) { self.text = Text(text) }
    init(verbatim: String) { self.text = Text(verbatim: verbatim) }

    var body: some View {
        text
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tint)
            .padding(.leading, 4)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

struct GroupDivider: View {
    var inset: CGFloat = 16

    init(inset: CGFloat = 16) { self.inset = inset }

    var body: some View {
        Divider().padding(.leading, inset)
    }
}

struct GroupText: View {
    private let text: Text
    private let isError: Bool

    init(_ text: LocalizedStringKey, isError: Bool = false) {
        self.text = Text(text)
        self.isError = isError
    }

    init(verbatim: String, isError: Bool = false) {
        self.text = Text(verbatim: verbatim)
        self.isError = isError
    }

    var body: some View {
        text
            .font(.subheadline)
            .foregroundStyle(isError ? Color.ipv64Red : Color.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }
}

/// Rounded card with an optional header; inserts `GroupDivider`s between its child views.
struct ListGroup<Content: View>: View {
    private let title: LocalizedStringKey?
    private let dividerInset: CGFloat
    private let content: Content

    init(_ title: LocalizedStringKey? = nil, dividerInset: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.title = title
        self.dividerInset = dividerInset
        self.content = content()
    }

    var body: some View {
        Group(subviews: content) { subviews in
            if !subviews.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    if let title { SectionHeader(title) }
                    VStack(spacing: 0) {
                        ForEach(subviews: subviews) { subview in
                            if subview.id != subviews.first?.id { GroupDivider(inset: dividerInset) }
                            subview.padding(.horizontal, 16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}

/// Card whose content is one padded column (no automatic dividers).
struct FormSection<Content: View>: View {
    private let title: LocalizedStringKey?
    private let content: Content

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ListGroup(title) {
            VStack(alignment: .leading, spacing: 8) { content }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ListGroup("Title") {
                Text("One").padding(.vertical, 12)
                Text("Two").padding(.vertical, 12)
                GroupText("Hint text")
                GroupText(verbatim: "Error", isError: true)
            }
            FormSection("Form") { Text("Field"); Text("Field 2") }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
