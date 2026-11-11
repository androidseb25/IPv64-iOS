import UIKit

/// The one way to copy text in the app: copies and confirms with a success vibration.
enum Clipboard {
    /// `sensitive`: stays on this device (no Universal Clipboard) and expires after 2 minutes (keys, update URLs).
    static func copy(_ text: String, sensitive: Bool = false) {
        if sensitive {
            UIPasteboard.general.setItems([["public.utf8-plain-text": text]],
                                          options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
        } else {
            UIPasteboard.general.string = text
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
