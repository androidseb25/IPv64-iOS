import SwiftUI

// The only place with `#available(iOS 27.x)` checks (iPhone Duo / adaptive bars). Layout itself reacts to
// available space only: no UIDevice / idiom / UIScreen / orientation branches anywhere in the app.

enum AppSheetPlacement { case automatic, center, leading, trailing }

extension View {
    /// Sidebar on the inner display (iOS 27.0+); no-op before.
    @ViewBuilder
    func appSidebarTabPlacement() -> some View {
        if #available(iOS 27.0, *) {
            defaultTabBarPlacement(.sidebar)
        } else {
            self
        }
    }

    @ViewBuilder
    func appSheetPlacement(_ p: AppSheetPlacement) -> some View {
        if #available(iOS 27.0, *) {
            switch p {
            case .automatic: presentationPlacement(.automatic)
            case .center: presentationPlacement(.center)
            case .leading: presentationPlacement(.leading)
            case .trailing: presentationPlacement(.trailing)
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func appPrefersToolbarItems() -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalCompressionBehavior(.prefersToolbarItems)
        } else {
            self
        }
    }

    /// Caps scrolling content (lists, forms) at a readable width; the list background still spans the
    /// whole container. Re-evaluated on every size change (split view, Stage Manager, fold).
    func appReadableWidth(_ maxWidth: CGFloat = 700) -> some View {
        modifier(ReadableWidth(maxWidth: maxWidth))
    }
}

private struct ReadableWidth: ViewModifier {
    let maxWidth: CGFloat
    @State private var inset: CGFloat = 0

    func body(content: Content) -> some View {
        // Safe-area padding (not frame/contentMargins): no identity change and nothing leaks into sheets.
        content
            .safeAreaPadding(.horizontal, inset)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                inset = max(0, ((width - maxWidth) / 2).rounded())
            }
    }
}

extension ToolbarContent {
    /// Keeps the item visible when the bar is compressed (iOS 27.0+).
    @ToolbarContentBuilder
    func appVisibilityPriorityHigh() -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            visibilityPriority(.high)
        } else {
            self
        }
    }

    /// Lets the item move into the overflow menu first (iOS 27.0+).
    @ToolbarContentBuilder
    func appVisibilityPriorityLow() -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            visibilityPriority(.low)
        } else {
            self
        }
    }
}

/// Secondary toolbar actions: the system overflow menu on iOS 27+ (`ToolbarOverflowMenu`),
/// a trailing "More" menu before.
struct AppMoreMenu<Content: View>: ToolbarContent {
    private let title: LocalizedStringKey
    private let isDisabled: Bool
    private let content: Content

    init(_ title: LocalizedStringKey = "More", disabled: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isDisabled = disabled
        self.content = content()
    }

    var body: some ToolbarContent {
        if #available(iOS 27.0, *) {
            ToolbarOverflowMenu { content.disabled(isDisabled) }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Menu(title, systemImage: AppSymbol.more) { content }
                    .disabled(isDisabled)
            }
        }
    }
}

#Preview {
    NavigationStack {
        List { Text("Adaptive") }
            .appReadableWidth()
            .navigationTitle("Adaptive")
            .appPrefersToolbarItems()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {}
                }
                .appVisibilityPriorityHigh()
                AppMoreMenu {
                    Button("Refresh", systemImage: "arrow.clockwise") {}
                }
            }
    }
}
