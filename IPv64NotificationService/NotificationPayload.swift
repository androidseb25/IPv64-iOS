import Foundation

/// SecNtfy push content (Android `SecNtfyMessagingService.processNotification`): RSA-encrypted title, body and
/// optional image URL, plus the message id for the receipt.
struct NotificationPayload: Equatable, Sendable {
    var title: String
    var body: String
    var image: String
    var messageId: String

    /// Message id keys in order: SecNtfy's APNs payload sends `msgId` (String or number); `messageId` | `id` as on Android.
    static let idKeys = ["msgId", "messageId", "id"]

    /// Title/body come from `aps.alert` (already parsed by the system); image and id from custom keys
    /// (top level of `userInfo` or inside `data`).
    static func parse(title: String, body: String, userInfo: [AnyHashable: Any]) -> NotificationPayload {
        let places = [userInfo, userInfo["data"] as? [AnyHashable: Any] ?? [:]]
        func string(_ key: String) -> String? {
            places.lazy.compactMap { $0[key] }.first
                .map { String(describing: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap { $0.isEmpty ? nil : $0 }
        }
        return NotificationPayload(title: title, body: body, image: string("image") ?? "",
                                   messageId: idKeys.lazy.compactMap(string).first ?? "")
    }

    /// Key names of the payload (nested as `data.x`), without values, for the log when no id is found.
    static func keyNames(_ userInfo: [AnyHashable: Any]) -> String {
        userInfo.flatMap { key, value -> [String] in
            let name = String(describing: key)
            guard let nested = value as? [AnyHashable: Any] else { return [name] }
            return nested.keys.map { "\(name).\($0)" }
        }.sorted().joined(separator: ", ")
    }

    /// Shown until decryption succeeds (Android defaults).
    static let defaultTitle = "IPv64.net Notification"
    static let defaultBody = "New notification received"
}
