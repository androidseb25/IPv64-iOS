import SwiftUI

extension View {
    /// iPhone Duo: keeps this screen's bars horizontal. Only for the documented exception of a sheet with a single
    /// text control (Skip/Done must stay text, a title-only item would not appear in a vertical bar).
    @ViewBuilder
    func appHorizontalBars() -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
    }

    /// Caps the content at a readable width on wide windows (inner Duo display, iPad, landscape) and centres it.
    /// Content margins of the scroll views instead of a frame: no identity change when the width changes, so state survives folding.
    func appReadableWidth(_ maxWidth: CGFloat = 720) -> some View {
        modifier(ReadableWidth(maxWidth: maxWidth))
    }
}

private struct ReadableWidth: ViewModifier {
    let maxWidth: CGFloat
    @State private var margins = EdgeInsets()

    func body(content: Content) -> some View {
        content
            // Scroll content margins don't add to the safe area (the larger one wins), so the safe area of a
            // vertical bar is included to keep the column centred in the free space.
            .contentMargins(.leading, margins.leading, for: .scrollContent)
            .contentMargins(.trailing, margins.trailing, for: .scrollContent)
            .onGeometryChange(for: EdgeInsets.self) { proxy in
                let extra = max(0, ((proxy.size.width - maxWidth) / 2).rounded())
                guard extra > 0 else { return EdgeInsets() }
                return EdgeInsets(top: 0, leading: extra + proxy.safeAreaInsets.leading,
                                  bottom: 0, trailing: extra + proxy.safeAreaInsets.trailing)
            } action: { margins = $0 }
    }
}
