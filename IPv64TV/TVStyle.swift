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
}

/// `@AppStorage` keys of the Settings tab.
enum TVSettings {
    /// Keep the Apple TV awake (no screensaver) while the dashboard is on screen. Default on.
    static let keepAwake = "tvKeepAwake"
    /// Streaming mode: mask addresses, IPs, client names and domains on screen (`Streaming`). Default off.
    static let streamingMode = "tvStreamingMode"
}
