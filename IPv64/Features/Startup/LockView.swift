import SwiftUI
import UIKit

/// Lock screen (spec 01 §3b): icon + "Start Authentication".
struct LockView: View {
    let onAuthenticate: () -> Void

    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: Biometrics.symbol)
                .font(.system(size: 65))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Button("Start Authentication", action: onAuthenticate)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

extension View {
    /// Shows `content` in its own window above everything (also above sheets and alerts),
    /// like Android's lock Dialog window.
    func lockWindow<Content: View>(isPresented: Bool, @ViewBuilder content: @escaping () -> Content) -> some View {
        background(LockWindowAnchor(isPresented: isPresented, content: content))
    }
}

private struct LockWindowAnchor<Content: View>: UIViewRepresentable {
    let isPresented: Bool
    let content: () -> Content

    final class AnchorView: UIView {
        var overlay: UIWindow?
        var wanted = false
        var makeRoot: (() -> AnyView)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            update()
        }

        func update() {
            if wanted, overlay == nil, let scene = window?.windowScene, let makeRoot {
                let window = UIWindow(windowScene: scene)
                window.windowLevel = .alert + 1
                window.rootViewController = UIHostingController(rootView: makeRoot())
                window.isHidden = false
                overlay = window
            } else if !wanted, let overlay {
                overlay.isHidden = true
                self.overlay = nil
            }
        }
    }

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: AnchorView, context: Context) {
        let content = content
        view.makeRoot = { AnyView(content()) }
        view.wanted = isPresented
        view.update()
    }

    static func dismantleUIView(_ view: AnchorView, coordinator: ()) {
        view.overlay?.isHidden = true
        view.overlay = nil
    }
}
