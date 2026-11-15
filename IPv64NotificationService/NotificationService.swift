import UserNotifications
import UniformTypeIdentifiers
import SecNtfy
@preconcurrency import SwiftyBeaver

/// Decrypts SecNtfy pushes (needs `mutable-content: 1`), sends the receipt and attaches an image if the payload has one.
/// Flow as in iGotify: readable fallback first, decrypt, then receipt (`Status 201` = already received → delivered
/// silently, no badge), then the image. Keys come from the App Group the app passes to `SecNtfySwifty.initialize`.
///
/// `@unchecked Sendable` invariant: `handler`, `fallback`, `finished` and `task` are only touched while holding
/// `lock`; processing and `serviceExtensionTimeWillExpire` may race, `deliverOnce` hands content over exactly once.
final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
    private static let appGroup = "group.ipv64.net"

    /// Writes into the app's daily log file (More → Tools → System Logs; name as in `iLogger.defaultLogFileURL`,
    /// the app rotates it). Synchronous writes: the process may be frozen right after the handler is called.
    /// Never log message contents, keys or tokens.
    private static let log: SwiftyBeaver.Type = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("app_\(formatter.string(from: Date()))_latest.log") {
            let file = FileDestination(logFileURL: url)
            file.asynchronously = false
            SwiftyBeaver.addDestination(file)
        }
        return SwiftyBeaver.self
    }()

    private let lock = NSLock()
    private var handler: ((UNNotificationContent) -> Void)?
    private var fallback: UNNotificationContent?
    private var finished = false
    private var task: Task<Void, Never>?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        let payload = NotificationPayload.parse(title: content.title, body: content.body, userInfo: content.userInfo)
        // Readable text before any work, so the expiration path never shows ciphertext.
        content.title = NotificationPayload.defaultTitle
        content.body = NotificationPayload.defaultBody
        lock.withLock {
            handler = contentHandler
            fallback = content.copy() as? UNNotificationContent
            finished = false
        }
        // Handed over to the task: didReceive doesn't touch `content` after this point.
        nonisolated(unsafe) let owned = content
        let work = Task { [weak self] in
            guard let self else { return }
            await process(payload, content: owned)
        }
        lock.withLock { if finished { work.cancel() } else { task = work } }
    }

    override func serviceExtensionTimeWillExpire() {
        Self.log.warning("Push extension: time expired")
        if let content = lock.withLock({ fallback }) { deliverOnce(content, reason: "time expired") }
    }

    private func process(_ payload: NotificationPayload, content: UNMutableNotificationContent) async {
        guard !payload.messageId.isEmpty else {
            Self.log.error("Push extension: no message id (payload keys: \(NotificationPayload.keyNames(content.userInfo)))")
            deliverOnce(content, reason: "missing message id")
            return
        }
        let id = payload.messageId
        Self.log.info("Push extension: received \(id)")
        guard let title = decrypt(payload.title), let body = decrypt(payload.body) else {
            Self.log.error("Push extension: decryption failed for \(id)")
            deliverOnce(content, reason: "decryption failed")
            return
        }
        content.title = title
        content.body = body
        snapshot(content)

        // Receipt only after decryption, so a failed decrypt never consumes the message id.
        let duplicate = await Self.receipt(id)
        if Task.isCancelled { return }
        if duplicate {
            content.sound = nil
            content.badge = nil
            content.interruptionLevel = .passive
            deliverOnce(content, reason: "duplicate")
            return
        }
        content.badge = NSNumber(value: Self.nextBadgeCount())
        snapshot(content)

        if let image = decrypt(payload.image), image.lowercased().hasPrefix("https://"), let url = URL(string: image) {
            if let attachment = await Self.downloadAttachment(url) {
                content.attachments = [attachment]
            } else {
                Self.log.warning("Push extension: image could not be loaded for \(id)")
            }
        }
        if Task.isCancelled { return }
        deliverOnce(content, reason: "delivered")
    }

    private func decrypt(_ text: String) -> String? {
        text.isEmpty ? nil : SecNtfySwifty.OfflineDecryption(text, Self.appGroup)
    }

    /// `POST /Message/Receive/{id}`; returns whether SecNtfy already had it (`Status 201`). Errors count as new.
    private static func receipt(_ id: String) async -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let apiURL = defaults.string(forKey: "NTFY_API_URL"), let base = URL(string: apiURL),
              let device = defaults.string(forKey: "NTFY_DEVICE_TOKEN"), !device.isEmpty else {
            log.error("Push extension: receipt configuration missing")
            return false
        }
        var request = URLRequest(url: base.appendingPathComponent("Message").appendingPathComponent("Receive")
            .appendingPathComponent(id))
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        request.setValue(device, forHTTPHeaderField: "X-NTFYME-DEVICE-KEY")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(code) else {
                log.error("Push extension: receipt failed for \(id), HTTP \(code)")
                return false
            }
            let duplicate = (try? JSONDecoder().decode(ReceiptResponse.self, from: data))?.status == 201
            log.info("Push extension: receipt sent for \(id)\(duplicate ? " (already received)" : "")")
            return duplicate
        } catch {
            log.error("Push extension: receipt failed for \(id): \(error.localizedDescription)")
            return false
        }
    }

    private struct ReceiptResponse: Decodable {
        let status: Int
        enum CodingKeys: String, CodingKey { case status = "Status" }
    }

    /// Unread counter shared with the app (App Group key `BADGE_COUNT`); the app resets it when it is opened.
    private static func nextBadgeCount() -> Int {
        let defaults = UserDefaults(suiteName: appGroup)
        let count = (defaults?.integer(forKey: "BADGE_COUNT") ?? 0) + 1
        defaults?.set(count, forKey: "BADGE_COUNT")
        return count
    }

    /// Latest state for the expiration path.
    private func snapshot(_ content: UNNotificationContent) {
        guard let copy = content.copy() as? UNNotificationContent else { return }
        lock.withLock { if !finished { fallback = copy } }
    }

    private func deliverOnce(_ content: UNNotificationContent, reason: String) {
        let taken: (handler: (UNNotificationContent) -> Void, task: Task<Void, Never>?)? = lock.withLock {
            guard !finished, let handler else { return nil }
            finished = true
            self.handler = nil
            let task = self.task
            self.task = nil
            return (handler, task)
        }
        guard let taken else { return }
        taken.task?.cancel()
        Self.log.info("Push extension: completed (\(reason))")
        taken.handler(content)
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
