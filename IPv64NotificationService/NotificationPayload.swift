import Foundation

/// SecNtfy push content (Android `SecNtfyMessagingService.processNotification`): RSA-encrypted title, body and
/// optional image URL, plus the message id for the receipt.
struct NotificationPayload: Equatable, Sendable {
    var title: String
    var body: String
    var image: String
    var messageId: String

    /// Title/body come from `aps.alert` (already parsed by the system); image and id from custom keys
    /// (`image`, `messageId` | `id`, top level or inside `data`, like Android).
    static func parse(title: String, body: String, userInfo: [AnyHashable: Any]) -> NotificationPayload {
        let data = userInfo["data"] as? [AnyHashable: Any] ?? [:]
        func string(_ key: String) -> String? {
            (userInfo[key] ?? data[key]).map { String(describing: $0) }?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return NotificationPayload(title: title, body: body, image: string("image") ?? "",
                                   messageId: string("messageId") ?? string("id") ?? "")
    }

    /// Decrypts each part; empty title/body get the Android defaults, a failed decryption keeps the raw value.
    func decrypted(_ decrypt: (String) -> String?) -> NotificationPayload {
        NotificationPayload(
            title: title.isEmpty ? "IPv64.net Notification" : decrypt(title) ?? title,
            body: body.isEmpty ? "New notification received" : decrypt(body) ?? body,
            image: image.isEmpty ? "" : decrypt(image) ?? image,
            messageId: messageId)
    }

    /// Only `https://` images are downloaded.
    var imageURL: URL? {
        guard image.lowercased().hasPrefix("https://") else { return nil }
        return URL(string: image)
    }
}
