import SwiftUI

extension View {
    /// Liquid Glass on iOS 26+, regular material before. Do not use inside scrolling content.
    @ViewBuilder
    func appGlass<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
        }
    }

    func appGlass() -> some View {
        appGlass(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Capsule chip surface (glass on iOS 26+, material / tint fill before).
    @ViewBuilder
    func appChip(selected: Bool, tint: Color = .accentColor) -> some View {
        if #available(iOS 26, *) {
            glassEffect(selected ? .regular.tint(tint).interactive() : .regular.interactive(), in: .capsule)
        } else {
            background(selected ? AnyShapeStyle(tint.opacity(0.25)) : AnyShapeStyle(.regularMaterial), in: Capsule())
        }
    }
}

/// Pressed feedback for tiles; solid surface because tiles live in scroll views.
struct AppTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// `GlassEffectContainer` on iOS 26+, plain content before.
struct AppGlassGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

#Preview {
    AppGlassGroup {
        HStack {
            Text("Chip").padding(.horizontal, 12).padding(.vertical, 6).appChip(selected: true)
            Text("Chip").padding(.horizontal, 12).padding(.vertical, 6).appChip(selected: false)
        }
        Text("Card").padding().appGlass()
    }
    .padding()
}
