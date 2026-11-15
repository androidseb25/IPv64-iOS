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
                        Image(systemName: "eye.slash").font(.largeTitle).foregroundStyle(.secondary)
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

/// Moves each window's layer into the secure canvas of a password field, which iOS leaves out of screenshots and
/// recordings. Touches and layout are unaffected (only the layer moves, the view tree stays).
/// shortcut: relies on UITextField's private canvas subview; if a future iOS changes it, `secure` does nothing
/// and only the cover above remains — check after each major iOS update.
@MainActor private enum ScreenshotShield {
    private static var fields: [ObjectIdentifier: UITextField] = [:]

    static func apply(_ on: Bool) {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        for window in windows { on ? secure(window) : release(window) }
    }

    private static func secure(_ window: UIWindow) {
        let id = ObjectIdentifier(window)
        guard fields[id] == nil, let superlayer = window.layer.superlayer else { return }
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false
        window.addSubview(field)
        field.layoutIfNeeded()
        guard let canvas = field.subviews.first(where: { String(describing: type(of: $0)).contains("CanvasView") })
                ?? field.subviews.first else {
            field.removeFromSuperview()
            return
        }
        superlayer.addSublayer(field.layer)
        canvas.layer.addSublayer(window.layer)
        fields[id] = field
    }

    private static func release(_ window: UIWindow) {
        guard let field = fields.removeValue(forKey: ObjectIdentifier(window)),
              let superlayer = field.layer.superlayer else { return }
        superlayer.addSublayer(window.layer)
        field.layer.removeFromSuperlayer()
        field.removeFromSuperview()
    }
}

extension View {
    func screenshotProtected(_ enabled: Bool) -> some View { modifier(ScreenshotProtection(enabled: enabled)) }
}
