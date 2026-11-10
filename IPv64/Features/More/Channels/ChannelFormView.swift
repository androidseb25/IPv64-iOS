import SwiftUI
import IPv64

/// Channel form (spec 04 §6.3–6.6): general settings, the type's dynamic fields, create / update / test / delete.
struct ChannelFormView: View {
    enum Mode {
        case new(HC2ChannelType)
        case edit(Int)
    }

    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    let mode: Mode

    @State private var channel: HC2Channel?
    @State private var type: HC2ChannelType?
    @State private var loaded = false
    @State private var name = ""
    @State private var enabled = true
    @State private var isDefault = false
    @State private var notifyDown = true
    @State private var notifyUp = true
    @State private var lang = ChannelLogic.systemLanguage
    @State private var values: [String: String] = [:]
    @State private var touched: Set<String> = []
    @State private var showValidation = false
    @State private var verifiedNow = false
    @State private var busyText: LocalizedStringKey?
    @State private var error: ErrorText?
    @State private var loadError: ErrorText?
    @State private var message: FormMessage?
    @State private var confirm: ConfirmRequest?
    @State private var verify: VerifyTarget?
    @State private var savedPrompt: VerifyTarget?

    private var isEdit: Bool { if case .edit = mode { true } else { false } }
    private var deviceChannelId: Int? { PushSetupStore.channelId(apiKey: session.apiKey) }
    private var isThisDevice: Bool { channel != nil && channel?.id == deviceChannelId }
    private var awaitingVerification: Bool {
        guard let channel, !verifiedNow else { return false }
        return ChannelLogic.isAwaitingVerification(channel, types: type.map { [$0] })
    }

    /// App token field of an edited app channel stays hidden and unchanged.
    private var keepKeys: Set<String> {
        guard let channel, channel.type == .app else { return [] }
        return [PushTokenLogic.tokenKey(for: channel, appType: type)]
    }

    private var fields: [HC2ChannelType.Field] {
        (type?.fields ?? []).filter { $0.key?.nonBlank != nil && !keepKeys.contains($0.key ?? "") }
    }

    var body: some View {
        Form {
            if loaded {
                if awaitingVerification, let channel {
                    NotVerifiedSection { verify = VerifyTarget(id: channel.id, name: ChannelLogic.displayName(channel), justCreated: false) }
                }
                if let channel {
                    Section {
                        Label {
                            Text(verbatim: (channel.typeLabel ?? channel.type?.rawValue ?? "")
                                 + (isThisDevice ? " · " + String(localized: "This device") : ""))
                        } icon: { Image(systemName: ChannelLogic.systemImage(type: channel.type?.rawValue)) }
                    }
                }
                ChannelGeneralSection(name: $name, enabled: $enabled, isDefault: $isDefault, notifyDown: $notifyDown,
                                      notifyUp: $notifyUp, lang: $lang, showValidation: showValidation)
                fieldsSection
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .loadingOverlay(!loaded || busyText != nil, text: busyText ?? "Loading...")
        .task { await load() }
        .errorAlert($error)
        .alert(Text(verbatim: loadError?.title ?? ""), isPresented: isPresented($loadError), presenting: loadError) { _ in
            Button("Cancel", role: .cancel) { router.pop() }
            Button("Retry") { Task { await load() } }
        } message: { Text(verbatim: $0.message) }
        .alert(Text(verbatim: message?.title ?? ""), isPresented: isPresented($message), presenting: message) { msg in
            Button("OK", role: .cancel) { if msg.closeAfter { close() } }
        } message: { Text(verbatim: $0.text) }
        .alert("Channel saved", isPresented: isPresented($savedPrompt), presenting: savedPrompt) { target in
            Button("Later", role: .cancel) { close() }
            Button("Send test") { sendTest(id: target.id, closeAfter: true) }
        } message: { Text("Send a test notification to “\($0.name)” now?") }
        .confirmDialog($confirm)
        .sheet(item: $verify) { target in
            ChannelVerifySheet(channelId: target.id, name: target.name,
                               onVerified: { verified(target) },
                               onLater: { if target.justCreated { close() } })
        }
    }

    private var title: String {
        switch mode {
        case .new(let type): type.label?.nonBlank ?? String(localized: "New channel")
        case .edit: String(localized: "Edit channel")
        }
    }

    @ViewBuilder
    private var fieldsSection: some View {
        let secrets = Set(channel?.secretsSet ?? [])
        if isEdit && type == nil {
            Section(channel?.typeLabel ?? String(localized: "Settings")) {
                Text("The settings of this channel type can only be changed at ipv64.net.")
            }
        } else if !fields.isEmpty || type?.needsVerification == true {
            Section {
                ForEach(fields, id: \.self) { field in
                    let key = field.key ?? ""
                    let required = field.required == true && !(isEdit && secrets.contains(key))
                    ChannelFieldRow(field: field, value: binding(key), required: required,
                                    error: showValidation ? ChannelLogic.fieldError(field, value: values[key] ?? "", required: required) : nil,
                                    secretIsSet: isEdit && secrets.contains(key))
                }
            } header: {
                Text(verbatim: type?.label?.nonBlank ?? channel?.typeLabel ?? String(localized: "Settings"))
            } footer: {
                if !isEdit && type?.needsVerification == true {
                    Text("After creating the channel, a verification code will be sent to confirm it.")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if case .edit(let id) = mode {
                Button("Send test", systemImage: "paperplane") { sendTest(id: id, closeAfter: false) }
                    .disabled(!loaded || awaitingVerification || busyText != nil)
                Button("Delete", systemImage: "trash", role: .destructive, action: askDelete)
                    .disabled(!loaded || busyText != nil)
            }
            Button("Save", systemImage: "checkmark", action: save)
                .disabled(!loaded || busyText != nil)
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0; touched.insert(key) })
    }

    private func isPresented<T>(_ value: Binding<T?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }

    private func close() {
        router.reload()
        router.pop()
    }
}

// MARK: - Loading and actions

private extension ChannelFormView {
    func load() async {
        switch mode {
        case .new(let type):
            guard !loaded else { return }
            self.type = type
            name = type.label ?? ""
            for field in type.fields ?? [] {
                if let key = field.key { values[key] = ChannelLogic.initialValue(field, config: nil, isEdit: false) }
            }
            loaded = true
        case .edit(let id):
            let client = session.api
            do {
                let types = try? await ipv64Retrying { try await client.hc2.channels.types() }
                let channel = try await ipv64Retrying { try await client.hc2.channels.get(id) }
                apply(channel, type: types?.first { $0.type == channel.type })
            } catch is CancellationError {
            } catch {
                loadError = ErrorText(error)
            }
        }
    }

    func apply(_ channel: HC2Channel, type: HC2ChannelType?) {
        self.channel = channel
        self.type = type
        name = channel.name ?? ""
        enabled = channel.enabled ?? true
        isDefault = channel.default ?? false
        notifyDown = channel.notifyDown ?? true
        notifyUp = channel.notifyUp ?? true
        if let lang = channel.lang, lang == .de || lang == .en { self.lang = lang }
        for field in type?.fields ?? [] {
            if let key = field.key { values[key] = ChannelLogic.initialValue(field, config: channel.config, isEdit: true) }
        }
        loaded = true
    }

    func save() {
        showValidation = true
        let secrets = Set(channel?.secretsSet ?? [])
        let invalid = fields.contains { field in
            let key = field.key ?? ""
            let required = field.required == true && !(isEdit && secrets.contains(key))
            return ChannelLogic.fieldError(field, value: values[key] ?? "", required: required) != nil
        }
        guard let trimmed = name.nonBlank?.trimmingCharacters(in: .whitespacesAndNewlines), !invalid else { return }
        let config = ChannelLogic.buildConfig(fields: fields, values: values, touched: touched,
                                              base: channel?.config, isEdit: isEdit, keepKeys: keepKeys)
        switch mode {
        case .new(let type): create(type, name: trimmed, config: config)
        case .edit(let id): update(id, name: trimmed, config: config)
        }
    }

    func create(_ type: HC2ChannelType, name: String, config: [String: JSONValue]) {
        let input = HC2ChannelInput(name: name, type: type.type, config: config, enabled: enabled, default: isDefault,
                                    lang: lang, notifyDown: notifyDown, notifyUp: notifyUp)
        let client = session.api
        Task {
            busyText = "Creating channel..."
            defer { busyText = nil }
            do {
                let created = try await ipv64Retrying { try await client.hc2.channels.create(input) }
                router.reload()
                let target = VerifyTarget(id: created.id, name: ChannelLogic.displayName(created), justCreated: true)
                if ChannelLogic.isAwaitingVerification(created, types: [type]) {
                    verify = target
                } else {
                    savedPrompt = target
                }
            } catch {
                self.error = ErrorText(error)
            }
        }
    }

    /// Only changed fields (name is always carried, GAP-7); nothing changed → back without a request.
    func update(_ id: Int, name: String, config: [String: JSONValue]) {
        guard let base = channel else { return }
        let configChanged = config != (base.config ?? [:])
        let baseLang = base.lang == .de || base.lang == .en ? base.lang : ChannelLogic.systemLanguage
        let input = HC2ChannelInput(
            name: name,
            config: configChanged ? config : nil,
            enabled: enabled != (base.enabled ?? true) ? enabled : nil,
            default: isDefault != (base.default ?? false) ? isDefault : nil,
            lang: lang != baseLang ? lang : nil,
            notifyDown: notifyDown != (base.notifyDown ?? true) ? notifyDown : nil,
            notifyUp: notifyUp != (base.notifyUp ?? true) ? notifyUp : nil)
        guard name != (base.name ?? "") || input.config != nil || input.enabled != nil || input.default != nil
                || input.lang != nil || input.notifyDown != nil || input.notifyUp != nil else {
            router.pop()
            return
        }
        let client = session.api
        Task {
            busyText = "Saving..."
            defer { busyText = nil }
            do {
                _ = try await ipv64Retrying { try await client.hc2.channels.update(id, input) }
                close()
            } catch {
                self.error = ErrorText(error)
            }
        }
    }

    func sendTest(id: Int, closeAfter: Bool) {
        let client = session.api
        Task {
            busyText = "Sending test..."
            defer { busyText = nil }
            do {
                let result = try await ipv64Retrying { try await client.hc2.channels.sendTest(id) }
                let text = ChannelLogic.testResultMessage(result)
                message = FormMessage(title: text.title, text: text.message, closeAfter: closeAfter)
            } catch {
                let text = ErrorText(error)
                message = FormMessage(title: text.title, text: text.message, closeAfter: closeAfter)
            }
        }
    }

    func askDelete() {
        guard let channel else { return }
        var text = String(localized: "“\(ChannelLogic.displayName(channel))” will be deleted. Checks using only this channel will notify default channels instead.")
        if isThisDevice { text += String(localized: " This device will no longer receive push notifications.") }
        confirm = ConfirmRequest(title: String(localized: "Delete channel?"), message: text,
                                 confirmLabel: String(localized: "Delete"), destructive: true) { delete(channel.id) }
    }

    func delete(_ id: Int) {
        let client = session.api
        let apiKey = session.apiKey
        Task {
            busyText = "Deleting..."
            defer { busyText = nil }
            do {
                try await ipv64Retrying { try await client.hc2.channels.delete(id) }
                if PushSetupStore.channelId(apiKey: apiKey) == id { PushSetupStore.clearChannel(apiKey: apiKey) }
                close()
            } catch {
                self.error = ErrorText(error)
            }
        }
    }

    func verified(_ target: VerifyTarget) {
        if target.justCreated {
            savedPrompt = target
        } else {
            verifiedNow = true
            router.reload()
        }
    }
}

struct VerifyTarget: Identifiable {
    let id: Int
    let name: String
    let justCreated: Bool
}

private struct FormMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let closeAfter: Bool
}

/// Orange "Not verified" block with "Verify now".
private struct NotVerifiedSection: View {
    let onVerify: () -> Void

    var body: some View {
        Section {
            Text("Not verified").font(.headline).foregroundStyle(Color.ipv64Orange)
            Text("This channel won't receive notifications and can't be tested until it is verified.")
            Button("Verify now", systemImage: "checkmark.shield", action: onVerify)
        }
        .listRowBackground(Color.ipv64Orange.opacity(0.15))
    }
}
