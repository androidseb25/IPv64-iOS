import SwiftUI
import IPv64

/// Channels (pushed from More): permission banner, "This device", all channels. Setup and edit are sheets.
struct ChannelsView: View {
    @Environment(Session.self) private var session
    @Environment(PushRegistrar.self) private var registrar

    @State private var channels: [HC2Channel]?
    @State private var types: [HC2ChannelType]?
    @State private var deviceChannelId: Int?
    @State private var permission = NotificationPermission.unknown
    @State private var sheet: ChannelSheet?
    @State private var confirmDelete: HC2Channel?
    @State private var isBusy = false
    @State private var error: ErrorText?
    @State private var message: ErrorText?

    enum ChannelSheet: Identifiable {
        case new, push
        case edit(Int)
        case verify(HC2Channel)

        var id: String {
            switch self {
            case .new: "new"
            case .push: "push"
            case .edit(let id): "edit\(id)"
            case .verify(let channel): "verify\(channel.id)"
            }
        }
    }

    private var deviceChannel: HC2Channel? { channels?.first { $0.id == deviceChannelId } }

    var body: some View {
        if #available(iOS 26.0, *) {
            listView.setColorGradient(sheet != nil || confirmDelete != nil ? .clear : .orange)
        } else {
            listView
        }
    }

    private var listView: some View {
        List {
            if permission == .canRequest || permission == .denied {
                Section {
                    Label("Notifications are disabled", systemImage: "bell.slash").font(.headline).foregroundStyle(.orange)
                    NotificationPermissionActions(permission: $permission)
                }
            }
            if let channels {
                deviceSection(hasDefault: channels.contains { $0.default == true })
                Section {
                    ForEach(channels) { channel in
                        // No outer Button: the "Not verified" tag is a button of its own.
                        ChannelRow(channel: channel, isThisDevice: channel.id == deviceChannelId,
                                   awaitingVerification: ChannelLogic.isAwaitingVerification(channel, types: types),
                                   onVerify: { sheet = .verify(channel) })
                            .contentShape(Rectangle())
                            .onTapGesture { sheet = .edit(channel.id) }
                            .accessibilityAddTraits(.isButton)
                        // This device's push channel can't be deleted here (it would silently stop its pushes).
                        .swipeActions {
                            if channel.id != deviceChannelId {
                                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = channel }
                                    .labelStyle(.iconOnly)
                                    .tint(.red)
                            }
                        }
                    }
                } header: {
                    Text("Channels")
                } footer: {
                    if channels.isEmpty { Text("No channels yet. Tap + to add one.") }
                }
            }
        }
        .overlay {
            if channels == nil || isBusy { ProgressView() }
        }
        .navigationTitle("Channels")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add channel", systemImage: "plus") { sheet = .new }.disabled(channels == nil)
            }
        }
        .refreshable { await load() }
        .trackingNotificationPermission($permission)
        .task { await load() }
        .errorAlert($error)
        .errorAlert($message)
        .alert("Delete channel?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
               presenting: confirmDelete) { channel in
            Button("Delete", role: .destructive) { delete(channel) }
            Button("Cancel", role: .cancel) {}
        } message: { channel in
            Text(deleteText(channel))
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .new:
                ChannelFormSheet(channelId: nil, onChanged: reload, onPush: { self.sheet = .push })
            case .edit(let id):
                ChannelFormSheet(channelId: id, onChanged: reload, onPush: { self.sheet = .push })
            case .push:
                NavigationStack { PushSetupView() }.tint(.orange).appReadableWidth()
                    .onDisappear(perform: reload)
            case .verify(let channel):
                ChannelVerifySheet(channelId: channel.id, name: ChannelLogic.displayName(channel), onVerified: reload)
            }
        }
    }

    private func deviceSection(hasDefault: Bool) -> some View {
        Section {
            if let channel = deviceChannel {
                Button { sheet = .edit(channel.id) } label: {
                    LabeledContent {
                        if channel.enabled == false { ChannelTag(text: "Disabled", color: .gray) }
                    } label: {
                        Label(ChannelLogic.displayName(channel), systemImage: "iphone")
                    }
                }
                .tint(.primary)
                Button("Send test", systemImage: "paperplane", action: sendTest)
            } else {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Push notifications")
                        Text("Receive healthcheck alerts as push notifications on this device.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "iphone") }
                Button("Set up push notifications", systemImage: "bell.badge") { sheet = .push }
            }
        } header: {
            Text("This device")
        } footer: {
            if !hasDefault { Text("No default channel set. Checks without explicit channels notify default channels.") }
        }
    }

    private func reload() { Task { await load() } }

    /// Account id, channels, types (failure tolerated), token sync (errors ignored), this device's channel.
    private func load() async {
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
            isBusy = true
            defer { isBusy = false }
            do {
                let result = try await ipv64Retrying { try await client.hc2.channels.sendTest(id) }
                let text = ChannelLogic.testResultMessage(result)
                message = ErrorText(title: text.title, message: text.message)
            } catch {
                self.error = ErrorText(error)
            }
        }
    }

    private func deleteText(_ channel: HC2Channel) -> String {
        String(localized: "“\(ChannelLogic.displayName(channel))” will be deleted. Checks using only this channel will notify default channels instead.")
    }

    private func delete(_ channel: HC2Channel) {
        let client = session.api
        let apiKey = session.apiKey
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await ipv64Retrying { try await client.hc2.channels.delete(channel.id) }
                if PushSetupStore.channelId(apiKey: apiKey) == channel.id { PushSetupStore.clearChannel(apiKey: apiKey) }
                await load()
            } catch {
                self.error = ErrorText(error)
            }
        }
    }
}

/// Compact row: name, type · target, trailing tags, last error.
private struct ChannelRow: View {
    let channel: HC2Channel
    let isThisDevice: Bool
    let awaitingVerification: Bool
    let onVerify: () -> Void

    /// Type label plus the first readable target of the (non-secret) config.
    private var subtitle: String {
        let type = channel.typeLabel?.nonBlank ?? channel.type?.rawValue ?? ""
        let target = ["email", "address", "phone", "number", "to", "url", "host", "chat_id", "topic", "channel"]
            .lazy.compactMap { key in channel.config?.first { $0.key.lowercased() == key }.flatMap { ChannelLogic.text($0.value).nonBlank } }
            .first
        return [type.nonBlank, target?.trimmingCharacters(in: .whitespacesAndNewlines)].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: ChannelLogic.displayName(channel)).font(.headline).lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 4) {
                    if isThisDevice { ChannelTag(text: "This device", color: .orange) }
                    if channel.default == true { ChannelTag(text: "Default", color: .blue) }
                    if channel.enabled == false { ChannelTag(text: "Disabled", color: .gray) }
                    if awaitingVerification {
                        Button(action: onVerify) { ChannelTag(text: "Not verified", color: .orange) }
                            .buttonStyle(.borderless)
                            .accessibilityHint(Text("Verify channel"))
                    }
                }
            }
            if let error = channel.lastError?.nonBlank {
                Text(verbatim: error.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.footnote).foregroundStyle(.red).lineLimit(2)
            }
        }
    }
}

struct ChannelTag: View {
    let text: LocalizedStringKey
    let color: Color

    var body: some View { HealthcheckTag(text: text, color: color) }
}
