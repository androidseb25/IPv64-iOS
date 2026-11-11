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

/// Step 2 "Register this device".
struct RegisterStep: View {
    @Binding var device: DeviceForm
    let registeredText: String?
    let appSupported: Bool?
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        Section {
            if let registeredText {
                Text(verbatim: registeredText)
            } else if appSupported == false {
                Text("Push notifications to the IPv64 app are not supported by the server yet. You can skip this step.")
            } else {
                if !AppConfig.isSecNtfyConfigured {
                    Text("The push service is not configured on this device yet. Registering may fail; try logging in again if it does.")
                        .foregroundStyle(Color.orange)
                }
                TextField("Device name *", text: $device.name)
                Toggle("Notify when a check goes down", isOn: $device.notifyDown)
                Toggle("Notify when a check recovers", isOn: $device.notifyUp)
                Toggle(isOn: $device.useAsDefault) {
                    Text("Use as default channel")
                    Text("Checks without explicit channels notify default channels.")
                }
                Button("Add this device", systemImage: "plus.circle", action: onAdd)
                    .disabled(!canAdd)
            }
        } header: {
            StepHeader(number: 2, title: "Register this device", done: registeredText != nil)
        }
    }
}

/// Step 3 "Send a test" (dimmed until registered).
struct TestStep: View {
    let registered: Bool
    let notificationsAllowed: Bool
    let resultText: String?
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

/// "Existing app channels" (dismissible): adopt one of them or create a new channel.
struct ExistingChannelsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let channels: [HC2Channel]
    let onAdopt: (Int) -> Void
    let onCreateNew: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(channels) { channel in
                        Button("Use existing channel “\(ChannelLogic.displayName(channel))”") { adopt(channel.id) }
                    }
                } footer: {
                    Text("This account already has app channels. If one of them is this device (for example after reinstalling the app or using a new API key), use it to avoid duplicate notifications.")
                }
            }
            .navigationTitle("Existing app channels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create new", action: createNew) }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func adopt(_ id: Int) {
        dismiss()
        onAdopt(id)
    }

    private func createNew() {
        dismiss()
        onCreateNew()
    }
}
