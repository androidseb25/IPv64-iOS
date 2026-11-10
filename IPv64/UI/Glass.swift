import SwiftUI

// The only place with `#available(iOS 26)` checks for Liquid Glass (Adaptive.swift holds the iOS 27 ones).
// System bars, the tab bar and sheets get glass from the system: never give them custom backgrounds.

extension View {
    /// Floating, non-button glass surface (snackbar, waiting banner, HUD); regular material before iOS 26.
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

    /// Card in a list row with a clear row background (KPI/stat tiles): glass on iOS 26+,
    /// the grouped cell fill before so it matches the surrounding list.
    @ViewBuilder
    func appCard() -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(Color(.secondarySystemGroupedBackground), in: shape)
        }
    }

    /// Toggle chip button: `.glassProminent` (tinted) when selected, `.glass` otherwise; bordered styles before iOS 26.
    @ViewBuilder
    func appChipButtonStyle(selected: Bool, tint: Color = .accentColor) -> some View {
        if #available(iOS 26, *) {
            if selected {
                buttonStyle(.glassProminent).tint(tint).buttonBorderShape(.capsule)
            } else {
                buttonStyle(.glass).buttonBorderShape(.capsule)
            }
        } else {
            if selected {
                buttonStyle(.borderedProminent).tint(tint).buttonBorderShape(.capsule)
            } else {
                buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
        }
    }

    /// Standalone button outside lists (welcome, lock, camera overlay): glass on iOS 26+, bordered before.
    @ViewBuilder
    func appGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }

    /// Contacts-style action tile: native `.glass` button on iOS 26+, grouped fill (`AppTileButtonStyle`) before.
    @ViewBuilder
    func appTileButtonStyle() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass).buttonBorderShape(.roundedRectangle(radius: 16))
        } else {
            buttonStyle(AppTileButtonStyle())
        }
    }

    /// Bottom-anchored bar content: `safeAreaBar` (scroll edge effect) on iOS 26+, `safeAreaInset` before.
    @ViewBuilder
    func appBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .bottom, content: bar)
        } else {
            safeAreaInset(edge: .bottom, content: bar)
        }
    }
}

enum AppSymbol {
    /// Filter toolbar symbol. iOS 26+: unenclosed (the toolbar glass is the enclosure), filled disc only while active.
    static func filter(active: Bool) -> String {
        if active { return "line.3.horizontal.decrease.circle.fill" }
        if #available(iOS 26, *) { return "line.3.horizontal.decrease" }
        return "line.3.horizontal.decrease.circle"
    }

    /// "More" menu symbol: plain ellipsis inside toolbar glass on iOS 26+, the classic circled one before.
    static var more: String {
        if #available(iOS 26, *) { return "ellipsis" }
        return "ellipsis.circle"
    }
}

/// iOS 18 tile surface (the grouped cell fill, like the Contacts action buttons).
struct AppTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
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
            Button("Chip") {}.appChipButtonStyle(selected: true)
            Button("Chip") {}.appChipButtonStyle(selected: false)
        }
        Text("Card").padding().appGlass()
    }
    .padding()
}
