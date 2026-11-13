import SwiftUI

extension View {
    /// iPhone Duo: keeps this screen's bars horizontal (sheet with a single text control Skip/Done).
    @ViewBuilder
    func appHorizontalBars() -> some View {
        if #available(iOS 27.1, *) { toolbarVerticalBehavior(.disabled) } else { self }
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
