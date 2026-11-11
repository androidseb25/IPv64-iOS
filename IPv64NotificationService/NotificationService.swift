import UserNotifications
import UniformTypeIdentifiers
import SecNtfy

/// Decrypts SecNtfy pushes (needs `mutable-content: 1`), acknowledges them and attaches an image if the payload has one.
/// Keys come from the shared App Group the app passes to `SecNtfySwifty.initialize(bundleGroup:)`.
///
/// `@unchecked Sendable` invariant: `handler` and `content` are only read or written while holding `lock`;
/// the image task and `serviceExtensionTimeWillExpire` may race, `deliver` hands the content over exactly once.
final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
    private static let appGroup = "group.ipv64.net"

    private let lock = NSLock()
    private var handler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        let payload = NotificationPayload.parse(title: content.title, body: content.body, userInfo: content.userInfo)
            .decrypted { SecNtfySwifty.OfflineDecryption($0, Self.appGroup) }
        content.title = payload.title
        content.body = payload.body
        content.badge = NSNumber(value: Self.nextBadgeCount())
        lock.withLock {
            handler = contentHandler
            self.content = content
        }
        // The SDK's synchronous receipt for extensions (5 s timeout); Android acks before loading the image as well.
        if !payload.messageId.isEmpty {
            _ = SecNtfySwifty.OfflineMessageReceived(payload.messageId, Self.appGroup)
        }
        guard let url = payload.imageURL else {
            deliver(attachment: nil)
            return
        }
        Task { [self] in deliver(attachment: await Self.downloadAttachment(url)) }
    }

    /// Unread counter shared with the app (App Group key `BADGE_COUNT`); the app resets it when it is opened.
    private static func nextBadgeCount() -> Int {
        let defaults = UserDefaults(suiteName: appGroup)
        let count = (defaults?.integer(forKey: "BADGE_COUNT") ?? 0) + 1
        defaults?.set(count, forKey: "BADGE_COUNT")
        return count
    }

    override func serviceExtensionTimeWillExpire() {
        deliver(attachment: nil)
    }

    private func deliver(attachment: UNNotificationAttachment?) {
        lock.withLock {
            guard let handler, let content else { return }
            if let attachment { content.attachments = [attachment] }
            handler(content)
            self.handler = nil
            self.content = nil
        }
    }

    /// Android: 4 s connect/read timeouts; the file needs a type extension for the attachment.
    private static func downloadAttachment(_ url: URL) async -> UNNotificationAttachment? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        guard let (file, response) = try? await session.download(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let ext = response.mimeType.flatMap { UTType(mimeType: $0)?.preferredFilenameExtension }
            ?? (url.pathExtension.isEmpty ? "jpg" : url.pathExtension)
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        guard (try? FileManager.default.moveItem(at: file, to: target)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "image", url: target)
    }
}
