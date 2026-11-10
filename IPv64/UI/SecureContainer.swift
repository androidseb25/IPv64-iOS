import SwiftUI
import UIKit

/// Hosts SwiftUI content inside the secure canvas of a secure `UITextField`, so the content is blank in
/// screenshots and screen recordings. Intended for leaf content (texts/boxes): only UIKit traits are
/// propagated, SwiftUI environment values and the tint are not. Falls back to plain rendering if the
/// canvas subview cannot be found.
struct SecureContainer<Content: View>: UIViewRepresentable {
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    func makeUIView(context: Context) -> SecureHostField<Content> {
        SecureHostField(rootView: content)
    }

    func updateUIView(_ uiView: SecureHostField<Content>, context: Context) {
        uiView.host.rootView = content
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: SecureHostField<Content>, context: Context) -> CGSize? {
        uiView.host.sizeThatFits(in: CGSize(width: proposal.width ?? 10_000, height: proposal.height ?? 10_000))
    }
}

final class SecureHostField<Content: View>: UITextField {
    let host: UIHostingController<Content>

    init(rootView: Content) {
        host = UIHostingController(rootView: rootView)
        super.init(frame: .zero)
        isSecureTextEntry = true
        isUserInteractionEnabled = true
        host.view.backgroundColor = .clear
        // The canvas is a private subview of a secure text field; match by class name and fall back to self.
        let canvas = subviews.first { String(describing: type(of: $0)).contains("CanvasView") } ?? self
        canvas.isUserInteractionEnabled = true
        canvas.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: canvas.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    override var canBecomeFirstResponder: Bool { false }
}

extension View {
    /// Covers the view with an opaque lock screen whenever the scene is not active
    /// (app switcher, control center). Closest iOS equivalent of Android FLAG_SECURE.
    func privacyProtected() -> some View { modifier(PrivacyProtected()) }
}

private struct PrivacyProtected: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.overlay {
            if scenePhase != .active {
                ZStack {
                    Color(.systemBackground)
                    Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.secondary)
                }
                .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    SecureContainer { Text(verbatim: "Hidden in screenshots").font(.body) }
        .privacyProtected()
}
