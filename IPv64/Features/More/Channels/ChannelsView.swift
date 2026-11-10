import SwiftUI
import IPv64

/// Channels list (spec 04 §5): permission banner, "This device", all channels (swipe to delete).
struct ChannelsView: View {
    @Environment(Session.self) private var session
    @Environment(PushRegistrar.self) private var registrar
    @Environment(Router.self) private var router

    @State private var channels: [HC2Channel]?
    @State private var types: [HC2ChannelType]?
    @State private var deviceChannelId: Int?
    @State private var permission = NotificationPermission.unknown
    @State private var isLoading = false
    @State private var busyText: LocalizedStringKey?
    @State private var error: ErrorText?
    @State private var message: ErrorText?
    @State private var confirm: ConfirmRequest?
    @State private var verifying: HC2Channel?

    private var deviceChannel: HC2Channel? { channels?.first { $0.id == deviceChannelId } }

    var body: some View {
        List {
            if permission == .canRequest || permission == .denied {
                PermissionBanner(permission: $permission)
            }
            if let channels {
                ThisDeviceSection(channel: deviceChannel, onSetUp: { router.push(.pushSetup) }, onSendTest: sendTest,
                                  showsNoDefaultHint: !channels.contains { $0.default == true })
                Section("Channels") {
                    if channels.isEmpty {
                        Text("No channels yet. Tap + to add one.").foregroundStyle(.secondary)
                    }
                    ForEach(channels) { channel in
                        NavigationLink(value: Route.channelEdit(id: channel.id)) {
                            ChannelRow(channel: channel, isThisDevice: channel.id == deviceChannelId,
                                       awaitingVerification: ChannelLogic.isAwaitingVerification(channel, types: types),
                                       onVerify: { verifying = channel })
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) { askDelete(channel) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Channels")
        .toolbar { toolbar }
        .loadingOverlay(isLoading || busyText != nil, text: busyText ?? "Loading...")
        .refreshable { await load() }
        .trackingNotificationPermission($permission)
        .task(id: "\(router.reloadToken)-\(session.accountRevision)") { await load() }
        .errorAlert($error) { Task { await load() } }
        .errorAlert($message)
        .confirmDialog($confirm)
        .sheet(item: $verifying) { channel in
            ChannelVerifySheet(channelId: channel.id, name: ChannelLogic.displayName(channel)) {
                Task { await load() }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
                .disabled(isLoading)
        }
        if channels != nil {
            ToolbarItem(placement: .primaryAction) {
                Button("Add channel", systemImage: "plus") { router.push(.channelNew) }
            }
            .appVisibilityPriorityHigh()
        }
    }

    /// Account id, channels, types (failure tolerated), token sync (errors ignored), this device's channel.
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        await registrar.ensureAccountId()
        let client = session.api
        do {
            let list = try await ipv64Retrying { try await client.hc2.channels.list() }
            let types = try? await ipv64Retrying { try await client.hc2.channels.types() }
            _ = try? await registrar.syncTokenIfChanged(channels: list)
            deviceChannelId = registrar.detectThisDevice(list, types: types)?.id
            self.types = types
            channels = list
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func sendTest() {
        guard let id = deviceChannelId else { return }
        let client = session.api
        Task {
            busyText = "Sending test..."
            defer { busyText = nil }
            do {
                let result = try await ipv64Retrying { try await client.hc2.channels.sendTest(id) }
                let text = ChannelLogic.testResultMessage(result)
                message = ErrorText(title: text.title, message: text.message)
            } catch {
                self.error = ErrorText(error)
            }
        }
    }

    private func askDelete(_ channel: HC2Channel) {
        var text = String(localized: "“\(ChannelLogic.displayName(channel))” will be deleted. Checks using only this channel will notify default channels instead.")
        if channel.id == deviceChannelId {
            text += String(localized: " This device will no longer receive push notifications.")
        }
        confirm = ConfirmRequest(title: String(localized: "Delete channel?"), message: text,
                                 confirmLabel: String(localized: "Delete"), destructive: true) { delete(channel.id) }
    }

    private func delete(_ id: Int) {
        let client = session.api
        let apiKey = session.apiKey
        Task {
            busyText = "Deleting..."
            defer { busyText = nil }
            do {
                try await ipv64Retrying { try await client.hc2.channels.delete(id) }
                if PushSetupStore.channelId(apiKey: apiKey) == id { PushSetupStore.clearChannel(apiKey: apiKey) }
                await load()
            } catch {
                self.error = ErrorText(error)
            }
        }
    }
}

/// Orange banner when the system permission is missing.
private struct PermissionBanner: View {
    @Binding var permission: NotificationPermission

    var body: some View {
        Section {
            Label("Notifications are disabled", systemImage: "bell.slash")
                .font(.headline)
                .foregroundStyle(Color.ipv64Orange)
            NotificationPermissionActions(permission: $permission)
        }
        .listRowBackground(Color.ipv64Orange.opacity(0.15))
    }
}

/// "This device": set up push or the registered device channel with "Send test".
private struct ThisDeviceSection: View {
    let channel: HC2Channel?
    let onSetUp: () -> Void
    let onSendTest: () -> Void
    let showsNoDefaultHint: Bool

    var body: some View {
        Section {
            if let channel {
                NavigationLink(value: Route.channelEdit(id: channel.id)) {
                    LabeledContent {
                        channel.enabled == false
                            ? StatusChip("Disabled", color: .ipv64Gray) : StatusChip("Enabled", color: .ipv64Teal)
                    } label: {
                        Label {
                            Text(verbatim: ChannelLogic.displayName(channel))
                            Text("This device")
                        } icon: { Image(systemName: "iphone") }
                    }
                }
                Button("Send test", systemImage: "paperplane", action: onSendTest)
            } else {
                Label {
                    Text("Push notifications")
                    Text("Receive healthcheck alerts as push notifications on this device.").lineLimit(3)
                } icon: { Image(systemName: "iphone") }
                Button("Set up push notifications", systemImage: "bell.badge", action: onSetUp)
            }
        } header: {
            Text("This device")
        } footer: {
            if showsNoDefaultHint {
                Text("No default channel set. Checks without explicit channels notify default channels.")
            }
        }
    }
}
