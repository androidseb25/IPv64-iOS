import UIKit
import UniformTypeIdentifiers

/// Android `copyText(label, text, sensitive)`. Never log the copied text.
enum Clipboard {
    /// Sensitive values stay on this device (no Universal Clipboard) and expire after 60 s.
    static func copy(_ text: String, sensitive: Bool = false) {
        let item = [UTType.plainText.identifier: text]
        if sensitive {
            UIPasteboard.general.setItems([item], options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(60),
            ])
        } else {
            UIPasteboard.general.setItems([item])
        }
    }
}
