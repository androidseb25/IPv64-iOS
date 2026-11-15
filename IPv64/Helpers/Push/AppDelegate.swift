import UIKit
import UserNotifications
import SwiftyBeaver

/// APNs registration (spec 01 §9): the token goes to SecNtfy via `PushRegistrar` on every launch.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Set by `IPv64App` once the scene is up; a token that arrived earlier is handed over then.
    var registrar: PushRegistrar? {
        didSet { deliverPendingToken() }
    }
    private var pendingToken: String?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        _ = iLogger.shared   // log file destination (System Logs)
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()   // no prompt; the permission is asked in Push setup step 1
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        pendingToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        deliverPendingToken()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        iLogger.log.warning("APNs registration failed: \(error.localizedDescription)")
    }

    private func deliverPendingToken() {
        guard let registrar, let token = pendingToken else { return }
        pendingToken = nil
        Task { await registrar.apnsTokenReceived(token) }
    }

    /// Show pushes while the app is open (the Notification Service Extension already decrypted them).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
