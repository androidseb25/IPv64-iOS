import SwiftUI
import IPv64

/// Numbered step header; a green seal replaces the number when the step is done.
private struct StepHeader: View {
    let number: Int
    let title: LocalizedStringKey
    let done: Bool

    var body: some View {
        HStack(spacing: 8) {
            if done {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.green)
                    .accessibilityLabel(Text("Done"))
            } else {
                Text(verbatim: "\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.accentColor))
            }
            Text(title)
        }
    }
}

/// Step 1 "Allow notifications".
struct AllowStep: View {
    @Binding var permission: NotificationPermission

    var body: some View {
        Section {
            switch permission {
            case .allowed: Text("Notifications are allowed.")
            case .unknown: ProgressView()
            case .canRequest, .denied: NotificationPermissionActions(permission: $permission)
            }
        } header: {
            StepHeader(number: 1, title: "Allow notifications", done: permission.isAllowed)
        }
    }
}

/// Step 2 "Register this device": runs by itself once notifications are allowed.
struct RegisterStep: View {
    let deviceName: String
    let permissionAllowed: Bool
    let registeredText: String?
    let appSupported: Bool?
    let isRegistering: Bool
    let failed: Bool
    let onRetry: () -> Void

    var body: some View {
        Section {
            LabeledContent("Device name", value: deviceName)
            if let registeredText {
                Text(verbatim: registeredText)
            } else if appSupported == false {
                Text("Push notifications to the IPv64 app are not supported by the server yet. You can skip this step.")
            } else if failed {
                Button("Try again", systemImage: "arrow.clockwise", action: onRetry)
            } else if isRegistering {
                HStack {
                    ProgressView()
                    Text("Registering this device...")
                }
            } else if !permissionAllowed {
                Text("Allow notifications first.").foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        } header: {
            StepHeader(number: 2, title: "Register this device", done: registeredText != nil)
        }
        .opacity(permissionAllowed || registeredText != nil ? 1 : 0.6)
    }
}

/// Step 3 "Send a test" (dimmed until registered).
struct TestStep: View {
    let registered: Bool
    let notificationsAllowed: Bool
    let resultText: String?
    let isSending: Bool
    let onTest: () -> Void
    let onDone: () -> Void

    var body: some View {
        Section {
            if registered {
                if !notificationsAllowed {
                    Text("Notifications are not allowed yet, so the test push won't be shown.")
                        .foregroundStyle(Color.orange)
                }
                Button("Send test notification", systemImage: "paperplane", action: onTest)
                    .disabled(isSending)
                if let resultText { Text(verbatim: resultText).font(.footnote) }
                Button(action: onDone) {
                    Text("Done").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Register this device first.").foregroundStyle(.secondary)
            }
        } header: {
            StepHeader(number: 3, title: "Send a test", done: false)
        }
        .opacity(registered ? 1 : 0.6)
    }
}
