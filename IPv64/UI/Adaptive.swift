import SwiftUI

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
}

#Preview {
    NavigationStack {
        Text("Adaptive").navigationTitle("Adaptive").appPrefersToolbarItems()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {}
                }
                .appVisibilityPriorityHigh()
            }
    }
}
