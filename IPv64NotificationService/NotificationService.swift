import UserNotifications
import UniformTypeIdentifiers
import SecNtfy
@preconcurrency import SwiftyBeaver

/// Decrypts SecNtfy pushes (needs `mutable-content: 1`), acknowledges them and attaches an image if the payload has one.
/// Keys come from the shared App Group the app passes to `SecNtfySwifty.initialize(bundleGroup:)`.
///
/// `@unchecked Sendable` invariant: `handler` and `content` are only read or written while holding `lock`;
/// the image task and `serviceExtensionTimeWillExpire` may race, `deliver` hands the content over exactly once.
final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
    private static let appGroup = "group.ipv64.net"
    /// Ids whose receipt succeeded; the app acks the others again when it sees the push (AppDelegate).
    static let ackedKey = "SECNTFY_ACKED_IDS"

    /// Notification log (More → Tools → Notification logs). Synchronous writes: the process may be frozen right
    /// after the handler is called. Never log message contents, keys or tokens.
    private static let log: SwiftyBeaver.Type = {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("secntfy_extension.log") {
            let file = FileDestination(logFileURL: url)
            file.asynchronously = false
            file.logFileAmount = 2
            file.logFileMaxSize = 512 * 1024
            SwiftyBeaver.addDestination(file)
        }
        return SwiftyBeaver.self
    }()

    private let lock = NSLock()
    private var handler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let raw = NotificationPayload.parse(title: request.content.title, body: request.content.body,
                                            userInfo: request.content.userInfo)
        Self.log.info("Push received, id \(raw.messageId.isEmpty ? "(none)" : raw.messageId)")
        // Receipt first, on every path (also when the content can't be changed or decryption fails): it tracks
        // whether pushes arrive. The SDK call is synchronous with a 5 s timeout; Android acks before the image too.
        Self.acknowledge(raw.messageId)

        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            Self.log.error("Push content not mutable, delivered unchanged")
            contentHandler(request.content)
            return
        }
        let payload = raw.decrypted { message in
            let plain = SecNtfySwifty.OfflineDecryption(message, Self.appGroup)
            if plain == nil { Self.log.error("Decryption failed, raw text kept") }
            return plain
        }
        content.title = payload.title
        content.body = payload.body
        content.badge = NSNumber(value: Self.nextBadgeCount())
        lock.withLock {
            handler = contentHandler
            self.content = content
        }
        guard let url = payload.imageURL else {
            deliver(attachment: nil)
            return
        }
        Task { [self] in
            let attachment = await Self.downloadAttachment(url)
            if attachment == nil { Self.log.warning("Image could not be loaded, delivered without it") }
            deliver(attachment: attachment)
        }
    }

    private static func acknowledge(_ messageId: String) {
        guard !messageId.isEmpty else {
            log.warning("No message id, receipt skipped")
            return
        }
        if SecNtfySwifty.OfflineMessageReceived(messageId, appGroup) {
            let defaults = UserDefaults(suiteName: appGroup)
            let acked = (defaults?.stringArray(forKey: ackedKey) ?? []) + [messageId]
            defaults?.set(Array(acked.suffix(100)), forKey: ackedKey)
            log.info("Receipt sent for \(messageId)")
        } else {
            log.error("Receipt failed for \(messageId), the app retries when it sees the push")
        }
    }

    /// Unread counter shared with the app (App Group key `BADGE_COUNT`); the app resets it when it is opened.
    private static func nextBadgeCount() -> Int {
        let defaults = UserDefaults(suiteName: appGroup)
        let count = (defaults?.integer(forKey: "BADGE_COUNT") ?? 0) + 1
        defaults?.set(count, forKey: "BADGE_COUNT")
        return count
    }

    override func serviceExtensionTimeWillExpire() {
        Self.log.warning("Time expired, delivered without image")
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
