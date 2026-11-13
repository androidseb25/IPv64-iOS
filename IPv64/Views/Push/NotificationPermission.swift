import SwiftUI
import UserNotifications

/// System notification permission (Android `rememberNotificationPermissionState`), re-read on every foreground.
enum NotificationPermission: Equatable {
    case unknown, canRequest, allowed, denied

    var isAllowed: Bool { self == .allowed }

    static func current() async -> NotificationPermission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .canRequest
        case .authorized, .provisional, .ephemeral: .allowed
        default: .denied
        }
    }

    static func request() async -> NotificationPermission {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        UIApplication.shared.registerForRemoteNotifications()
        return await current()
    }
}

extension View {
    /// Keeps `permission` current while the view is visible (Android: re-evaluated on ON_RESUME).
    func trackingNotificationPermission(_ permission: Binding<NotificationPermission>) -> some View {
        modifier(NotificationPermissionTracker(permission: permission))
    }
}

private struct NotificationPermissionTracker: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var permission: NotificationPermission

    func body(content: Content) -> some View {
        content.task(id: scenePhase) {
            if scenePhase == .active { permission = await NotificationPermission.current() }
        }
    }
}

/// Android `NotificationPermissionActions` (spec 04 §6.7): text + "Allow notifications"/"Settings" or "Open settings".
struct NotificationPermissionActions: View {
    @Environment(\.openURL) private var openURL
    @Binding var permission: NotificationPermission

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if permission == .canRequest {
                Text("Allow IPv64.net to show notifications so alerts can reach you.")
                ViewThatFits(in: .horizontal) {
                    HStack { permissionButtons }
                    VStack(alignment: .leading) { permissionButtons }
                }
            } else {
                Text("Notifications are turned off for IPv64.net. Turn them on in the system settings.")
                Button("Open settings", systemImage: "gear", action: openSettings)
                    .buttonStyle(.borderedProminent)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }

    @ViewBuilder private var permissionButtons: some View {
        // Text only: an SF Symbol in a bordered button inside a list row leaves an empty icon gap.
        Button("Allow notifications", action: allow)
            .buttonStyle(.borderedProminent)
        Button("Settings", action: openSettings)
            .buttonStyle(.bordered)
    }

    private func allow() {
        Task { permission = await NotificationPermission.request() }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
    }
}
