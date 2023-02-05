//
//  NotificationService.swift
//  NotificationService
//
//  Created by Sebastian Rank on 02.02.23.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            bestAttemptContent.title = "\(bestAttemptContent.title)"
            var badgeCount = SetupPrefs.readPreference(mKey: "BADGE_COUNT", mDefaultValue: 0) as! Int
            badgeCount = badgeCount + 1
            bestAttemptContent.badge = (badgeCount) as NSNumber
            SetupPrefs.setPreference(mKey: "BADGE_COUNT", mValue: badgeCount)
            var isImageAvailable = true
            guard let body = bestAttemptContent.userInfo["fcm_options"] as? Dictionary<String, Any>, let imageUrl = body["image"] as? String
            else {
                isImageAvailable = false
                return
                //fatalError("Image Link not found")
            }
            
            if (isImageAvailable) {
                print(imageUrl)
                downloadImageFrom(url: imageUrl) { (attachment) in
                    if let attachment = attachment {
                        bestAttemptContent.attachments = [attachment]
                        //bestAttemptContent.categoryIdentifier = "myNotificationCategory"  // Comment it for now
                        contentHandler(bestAttemptContent)
                    }
                }
            } else {
                contentHandler(bestAttemptContent)
            }
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    private func downloadImageFrom(url: String, handler: @escaping (UNNotificationAttachment?) -> Void) {
        let task = URLSession.shared.downloadTask(with: URL(string: url)!) { (downloadedUrl, response, error) in
            guard let downloadedUrl = downloadedUrl else { handler(nil) ; return } // RETURNING NIL IF IMAGE NOT FOUND
            var urlPath = URL(fileURLWithPath: NSTemporaryDirectory())
            let uniqueUrlEnding = ProcessInfo.processInfo.globallyUniqueString + ".jpg"
            urlPath = urlPath.appendingPathComponent(uniqueUrlEnding)
            try? FileManager.default.moveItem(at: downloadedUrl, to: urlPath)
            do {
                let attachment = try UNNotificationAttachment(identifier: "picture", url: urlPath, options: nil)
                handler(attachment) // RETURNING ATTACHEMENT HAVING THE IMAGE URL SUCCESSFULLY
            } catch {
                print("attachment error")
                handler(nil)
            }
        }
        task.resume()
    }

}
