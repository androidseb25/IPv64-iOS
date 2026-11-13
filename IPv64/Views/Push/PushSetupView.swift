import SwiftUI
import IPv64

/// Push notifications setup (spec 04 §7): 1 allow notifications, 2 register this device, 3 send a test.
/// Shown pushed (Route.pushSetup) or full screen after the first login; Skip / Done call
/// `PushSetupStore.markDone(apiKey:)` before closing (otherwise the start trigger fires again).
struct PushSetupView: View {
    @Environment(Session.self) private var session
    @Environment(PushRegistrar.self) private var registrar
    @Environment(\.dismiss) private var dismiss

    @State private var permission = NotificationPermission.unknown
    @State private var appSupported: Bool?
    @State private var deviceChannel: HC2Channel?
    @State private var detectedOnOpen = false
    @State private var initialLoadDone = false
    @State private var isRegistering = false
    @State private var deviceName = PushRegistrar.defaultDeviceName
    @State private var testText: String?
    @State private var isSendingTest = false
    @State private var error: ErrorText?
    @State private var message: ErrorText?
    @State private var finished = false

    private var registeredText: String? {
        guard let channel = deviceChannel else { return nil }
        let name = ChannelLogic.displayName(channel)
        if detectedOnOpen { return String(localized: "Already registered as “\(name)”. Its existing settings are kept.") }
        return String(localized: "Registered as “\(name)”.")
    }

    private var canRegister: Bool {
        permission.isAllowed && initialLoadDone && !isRegistering && deviceName.nonBlank != nil
    }

    // Shown as a sheet: no colour gradient (see CLAUDE.md).
    var body: some View {
        Form {
            Section {
                Label("Get a push notification on this device when a healthcheck goes down or recovers.", systemImage: "bell.badge")
            }
            AllowStep(permission: $permission)
            RegisterStep(deviceName: $deviceName, permissionAllowed: permission.isAllowed,
                         registeredText: registeredText, appSupported: appSupported,
                         isRegistering: isRegistering, canRegister: canRegister) {
                // Spinner at once and keyboard away; the first registration can take a while.
                isRegistering = true
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                Task { await register() }
            }
            TestStep(registered: deviceChannel != nil, notificationsAllowed: permission.isAllowed, resultText: testText,
                     isSending: isSendingTest, onTest: sendTest, onDone: finish)
        }
        .navigationTitle("Push notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(deviceChannel != nil ? "Done" : "Skip", action: finish)
            }
        }
        .interactiveDismissDisabled()
        .trackingNotificationPermission($permission)
        .task { await initialLoad() }
        .errorAlert($error)
        .errorAlert($message)
    }

    /// Mark done BEFORE closing; a second tap must not close twice.
    private func finish() {
        guard !finished else { return }
        finished = true
        PushSetupStore.markDone(apiKey: session.apiKey)
        dismiss()
    }

    /// Detects this device's channel (stored id or same token); failures surface when registering.
    private func initialLoad() async {
        defer { initialLoadDone = true }
        await registrar.ensureAccountId()
        let client = session.api
        guard let list = try? await ipv64Retrying({ try await client.hc2.channels.list() }) else { return }
        let types = try? await ipv64Retrying { try await client.hc2.channels.types() }
        appSupported = types.map { PushTokenLogic.appType($0) != nil }
        _ = try? await registrar.syncTokenIfChanged(channels: list)
        if deviceChannel == nil {
            deviceChannel = registrar.detectThisDevice(list, types: types)
            detectedOnOpen = deviceChannel != nil
        }
    }

    /// Always a new channel for this device, notifying on down and up and used as default.
    private func register() async {
        guard let name = deviceName.nonBlank?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        let settings = DeviceChannelSettings(name: name, isDefault: true, notifyDown: true,
                                             notifyUp: true, lang: ChannelLogic.systemLanguage)
        isRegistering = true
        defer { isRegistering = false }
        do {
            if case .registered(let channel, _) = try await registrar.registerThisDevice(settings, createNew: true) {
                deviceChannel = channel
                detectedOnOpen = false
                testText = nil
            }
        } catch is CancellationError {
            // Sheet closed while registering: nothing to report.
        } catch let error as URLError where error.code == .cancelled {
        } catch let failure as PushRegistrationError {
            message = ErrorText(title: failure.title, message: failure.message)
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func sendTest() {
        guard let id = deviceChannel?.id else { return }
        let client = session.api
        Task {
            isSendingTest = true
            defer { isSendingTest = false }
            do {
                let result = try await ipv64Retrying { try await client.hc2.channels.sendTest(id) }
                testText = result.sent == true ? String(localized: "Sent – you should get a push now.")
                    : result.queuedAtNode == true ? String(localized: "Queued – you should get a push shortly.")
                    : String(localized: "The server did not send the test notification.")
            } catch {
                self.error = ErrorText(error)
            }
        }
    }
}
