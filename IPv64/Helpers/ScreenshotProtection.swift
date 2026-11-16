import SwiftUI
import UIKit

/// Screenshot protection (More → App), like Android's FLAG_SECURE: screenshots and recordings show the app black,
/// and while the screen is recorded/mirrored or the app is inactive (app switcher snapshot) an opaque cover is shown.
private struct ScreenshotProtection: ViewModifier {
    let enabled: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var captured = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled && (captured || scenePhase != .active) {
                    ZStack {
                        Color(.systemBackground)
                        VStack(spacing: 12) {
                            Image(systemName: "eye.slash").font(.largeTitle)
                            Text("Screenshot protection is on")
                                .font(.headline)
                            Text("You can turn it off under More → App → Screenshot protection.")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.secondary)
                        .padding(32)
                    }
                    .ignoresSafeArea()
                }
            }
            .onAppear(perform: refresh)
            .onChange(of: enabled, initial: true) { ScreenshotShield.apply(enabled) }
            .onChange(of: scenePhase) { if scenePhase == .active { ScreenshotShield.apply(enabled) } }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in refresh() }
    }

    private func refresh() {
        captured = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .contains { $0.isCaptured }
    }
}

/// Hangs each window's layer into the secure layer of a password field, which iOS leaves out of screenshots and
/// recordings (same setup as ScreenProtectorKit: iOS 17+ uses the field's last sublayer). Touches and layout are
/// unaffected (only the layer moves, the view tree stays). Installed once per window; on/off only flips
/// `isSecureTextEntry`, so the layer tree is never rebuilt while the app runs.
/// shortcut: relies on UITextField's private layer layout; check after each major iOS update.
@MainActor private enum ScreenshotShield {
    private static var fields: [ObjectIdentifier: UITextField] = [:]

    static func apply(_ on: Bool) {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        for window in windows {
            if let field = fields[ObjectIdentifier(window)] {
                field.isSecureTextEntry = on
            } else if on {
                install(window)
            }
        }
    }

    private static func install(_ window: UIWindow) {
        guard let superlayer = window.layer.superlayer else { return }
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false
        // Zero-size field at the window origin: the window layer is positioned in the field's coordinates, so any
        // offset of the field (e.g. centring it) shifts the whole app on screen.
        window.addSubview(field)
        guard let secure = field.layer.sublayers?.last else {
            field.removeFromSuperview()
            return
        }
        superlayer.addSublayer(field.layer)
        secure.addSublayer(window.layer)
        fields[ObjectIdentifier(window)] = field
    }
}

extension View {
    func screenshotProtected(_ enabled: Bool) -> some View { modifier(ScreenshotProtection(enabled: enabled)) }
}
