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
    @State private var registrationFailed = false
    /// Bumped by "Try again"; part of the task id so a retry restarts the registration task.
    @State private var registerAttempt = 0
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

    /// Registration starts by itself once notifications are allowed (no button, always a new channel).
    /// Only inputs that do not change while it runs: a changing task id would cancel the running request.
    private struct RegisterTrigger: Equatable {
        let ready: Bool
        let attempt: Int
    }

    private var registerTrigger: RegisterTrigger {
        RegisterTrigger(ready: permission.isAllowed && initialLoadDone && appSupported != false, attempt: registerAttempt)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            form.setColorGradient(.orange)
        } else {
            form
        }
    }

    private var form: some View {
        Form {
            Section {
                Label("Get a push notification on this device when a healthcheck goes down or recovers.", systemImage: "bell.badge")
            }
            AllowStep(permission: $permission)
            RegisterStep(deviceName: PushRegistrar.defaultDeviceName,
                         permissionAllowed: permission.isAllowed, registeredText: registeredText,
                         appSupported: appSupported, isRegistering: isRegistering,
                         failed: registrationFailed, onRetry: retry)
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
        .task(id: registerTrigger) {
            if registerTrigger.ready, deviceChannel == nil, !registrationFailed { await register() }
        }
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
        let settings = DeviceChannelSettings(name: PushRegistrar.defaultDeviceName, isDefault: true, notifyDown: true,
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
            registrationFailed = true
            message = ErrorText(title: failure.title, message: failure.message)
        } catch {
            registrationFailed = true
            self.error = ErrorText(error)
        }
    }

    private func retry() {
        registrationFailed = false
        registerAttempt += 1
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
