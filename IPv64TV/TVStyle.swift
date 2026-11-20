import SwiftUI

extension Color {
    /// IPv64 orange (app icon, Display P3).
    static let ipv64 = Color(.displayP3, red: 0.945, green: 0.604, blue: 0.220)
}

extension View {
    /// Same header position on every tab, just below the floating tab bar. Each tab gets a different top
    /// inset from tvOS (tabs with a scroll view sit lower), so the page ignores it and uses a fixed padding.
    func tvPage() -> some View {
        padding(.horizontal, 60)
            .padding(.top, 180)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
    }

    /// A List/Form clips at its edges, which cut the grown focused row left and right (on tvOS it ignores
    /// `contentMargins`). Clipping is turned off; the mask clips again only above and below (12 pt for the lift),
    /// so scrolled rows don't draw over the header, while the sides stay open for the focus effect.
    func tvFocusRoom() -> some View {
        scrollClipDisabled()
            .mask { Rectangle().padding(.horizontal, -80).padding(.vertical, -12) }
    }
}

/// Focusable list row with its own focus look: white rounded platter, slight lift and shadow. The system list
/// platter renders coloured content in focused rows washed out; here colours stay as they are.
struct TVRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Row(configuration: configuration) }

    private struct Row: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var focused

        var body: some View {
            configuration.label
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .foregroundStyle(focused ? Color.black : Color.primary)
                .background { if focused { Capsule().fill(.white).shadow(color: .black.opacity(0.35), radius: 16, y: 8) } }
                .scaleEffect(configuration.isPressed ? 0.98 : focused ? 1.03 : 1)
                .animation(.easeOut(duration: 0.15), value: focused)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

/// `@AppStorage` keys of the Settings tab.
enum TVSettings {
    /// Keep the Apple TV awake (no screensaver) while the dashboard is on screen. Default on.
    static let keepAwake = "tvKeepAwake"
    /// Streaming mode: mask addresses, IPs, client names and domains on screen (`Streaming`). Default off.
    static let streamingMode = "tvStreamingMode"
    /// Build number whose "What's New" screen was last dismissed.
    static let lastWhatsNewBuild = "tvLastWhatsNewBuild"
}
