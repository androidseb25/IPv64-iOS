import SwiftUI

extension View {
    /// iPhone Duo: keeps this screen's bars horizontal (sheet with a single text control Skip/Done).
    @ViewBuilder
    func appHorizontalBars() -> some View {
        // compiler(>=6.4) = Xcode 27 with the iOS 27 SDK; older toolchains (CI runner) skip the iPhone Duo API.
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) { toolbarVerticalBehavior(.disabled) } else { self }
        #else
        self
        #endif
    }

    /// Caps the content at a readable width on wide windows and centres it.
    /// Narrow windows keep the system margins. Sheets apply it again to measure their own width.
    func appReadableWidth(_ maxWidth: CGFloat = 720) -> some View {
        modifier(ReadableWidth(maxWidth: maxWidth))
    }
}

private struct ReadableWidth: ViewModifier {
    let maxWidth: CGFloat
    /// `nil` = system default margin.
    @State private var leading: CGFloat?
    @State private var trailing: CGFloat?

    func body(content: Content) -> some View {
        content
            // Scroll content margins don't add to the safe area (the larger one wins), so the inset is included.
            .contentMargins(.leading, leading, for: .scrollContent)
            .contentMargins(.trailing, trailing, for: .scrollContent)
            .onGeometryChange(for: [CGFloat?].self) { proxy in
                let extra = ((proxy.size.width - maxWidth) / 2).rounded()
                guard extra > 0 else { return [nil, nil] }
                return [extra + proxy.safeAreaInsets.leading, extra + proxy.safeAreaInsets.trailing]
            } action: { margins in
                leading = margins[0]
                trailing = margins[1]
            }
    }
}

extension ToolbarContent {
    /// iPhone Duo: a custom view item (spinner swapped in while loading) joins the vertical bar
    /// instead of staying horizontal next to the status bar.
    @ToolbarContentBuilder
    func appVerticalPreferred() -> some ToolbarContent {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) { axisBehavior(.verticalPreferred) } else { self }
        #else
        self
        #endif
    }
}
