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
    @State private var device = DeviceForm()
    @State private var appSupported: Bool?
    @State private var deviceChannel: HC2Channel?
    @State private var reusedExisting = false
    @State private var detectedOnOpen = false
    @State private var initialLoadDone = false
    @State private var candidates: CandidateList?
    @State private var testText: String?
    @State private var busyText: LocalizedStringKey?
    @State private var error: ErrorText?
    @State private var message: ErrorText?
    @State private var finished = false

    private var registeredText: String? {
        guard let channel = deviceChannel else { return nil }
        let name = ChannelLogic.displayName(channel)
        if detectedOnOpen { return String(localized: "Already registered as “\(name)”. Its existing settings are kept.") }
        if reusedExisting { return String(localized: "Using the existing channel “\(name)” with your settings.") }
        return String(localized: "Registered as “\(name)”.")
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
            RegisterStep(device: $device, registeredText: registeredText, appSupported: appSupported,
                         canAdd: initialLoadDone && device.name.nonBlank != nil) { register() }
            TestStep(registered: deviceChannel != nil, notificationsAllowed: permission.isAllowed, resultText: testText,
                     onTest: sendTest, onDone: finish)
        }
        .navigationTitle("Push notifications")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if deviceChannel != nil {
                    Button("Done", systemImage: "checkmark", action: finish)
                } else {
                    Button("Skip", systemImage: "forward", action: finish)
                }
            }
        }
        .overlay {
            if let busyText {
                ProgressView(busyText).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .disabled(busyText != nil)
        .trackingNotificationPermission($permission)
        .task { await initialLoad() }
        .sheet(item: $candidates) { list in
            ExistingChannelsSheet(channels: list.channels,
                                  onAdopt: { register(adopt: $0) },
                                  onCreateNew: { register(createNew: true) })
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

    /// Detect an existing device channel and preset "Use as default"; failures surface when registering.
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
        if !device.defaultInitialized {
            // App channels do not count: a new device may become default in addition.
            device.useAsDefault = !list.contains { $0.default == true && $0.type != .app }
            device.defaultInitialized = true
        }
    }

    private func register(adopt: Int? = nil, createNew: Bool = false) {
        guard let name = device.name.nonBlank?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        let settings = DeviceChannelSettings(name: name, isDefault: device.useAsDefault, notifyDown: device.notifyDown,
                                             notifyUp: device.notifyUp, lang: ChannelLogic.systemLanguage)
        Task {
            busyText = "Registering this device..."
            defer { busyText = nil }
            do {
                switch try await registrar.registerThisDevice(settings, adoptChannelId: adopt, createNew: createNew) {
                case .registered(let channel, let reused):
                    deviceChannel = channel
                    reusedExisting = reused
                    detectedOnOpen = false
                    testText = nil
                case .existingCandidates(let channels):
                    candidates = CandidateList(channels: channels)
                }
            } catch let failure as PushRegistrationError {
                message = ErrorText(title: failure.title, message: failure.message)
            } catch {
                self.error = ErrorText(error)
            }
        }
    }

    private func sendTest() {
        guard let id = deviceChannel?.id else { return }
        let client = session.api
        Task {
            busyText = "Sending test..."
            defer { busyText = nil }
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

/// Step 2 input (Android rememberSaveable fields).
struct DeviceForm {
    var name = PushRegistrar.defaultDeviceName
    var notifyDown = true
    var notifyUp = true
    var useAsDefault = false
    /// "Use as default" is preset only once.
    var defaultInitialized = false
}

private struct CandidateList: Identifiable {
    let id = UUID()
    let channels: [HC2Channel]
}
