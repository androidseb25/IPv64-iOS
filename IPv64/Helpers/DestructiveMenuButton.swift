import SwiftUI
import UIKit

/// Destructive item of a `Menu`: red text and a red icon. `role: .destructive` alone colours only the text on some
/// iOS versions; an `.alwaysOriginal` red symbol image is drawn as is by the system menu.
struct DestructiveMenuButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            Label {
                Text(title)
            } icon: {
                Image(uiImage: (UIImage(systemName: systemImage) ?? UIImage())
                    .withTintColor(.systemRed, renderingMode: .alwaysOriginal))
            }
        }
    }
}
