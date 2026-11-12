import SwiftUI
import IPv64

/// Channel setup (`channelId == nil`: type picker + fields) or edit, shown as a sheet.
struct ChannelFormSheet: View {
    let channelId: Int?
    /// The list must reload (created, changed, deleted, verified).
    let onChanged: () -> Void
    /// "IPv64 App (this device)" was picked: the caller replaces this sheet with the push setup.
    let onPush: () -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var types: [HC2ChannelType] = []
    @State private var type: HC2ChannelType?
    @State private var channel: HC2Channel?
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
    @State private var isBusy = false
    @State private var error: ErrorText?
    @State private var loadError: ErrorText?
    @State private var message: FormMessage?
    @State private var confirmDelete = false
    @State private var verify: VerifyTarget?
    @State private var savedPrompt: VerifyTarget?

    private var isEdit: Bool { channelId != nil }
    private var isThisDevice: Bool { channel != nil && channel?.id == PushSetupStore.channelId(apiKey: session.apiKey) }
    private var awaitingVerification: Bool {
        guard let channel, !verifiedNow else { return false }
        return ChannelLogic.isAwaitingVerification(channel, types: type.map { [$0] })
    }

    /// The token field of an edited app channel stays hidden and unchanged.
    private var keepKeys: Set<String> {
        guard let channel, channel.type == .app else { return [] }
        return [PushTokenLogic.tokenKey(for: channel, appType: type)]
    }

    private var fields: [HC2ChannelType.Field] {
        (type?.fields ?? []).filter { $0.key?.nonBlank != nil && !keepKeys.contains($0.key ?? "") }
    }

    private var secrets: Set<String> { Set(channel?.secretsSet ?? []) }

    private func required(_ field: HC2ChannelType.Field) -> Bool {
        field.required == true && !(isEdit && secrets.contains(field.key ?? ""))
    }

    var body: some View {
        NavigationStack {
            Group {
                if loaded { form } else if loadError == nil { ProgressView() }
            }
            .navigationTitle(isEdit ? "Edit channel" : "New channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isBusy {
                        ProgressView()
                    } else {
                        Button(isEdit ? "Save" : "Create", action: save).disabled(!loaded || type == nil && !isEdit)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isBusy)
        .task { await load() }
        .errorAlert($error)
        .alert(Text(verbatim: loadError?.title ?? ""), isPresented: isPresented($loadError), presenting: loadError) { _ in
            Button("Cancel", role: .cancel) { dismiss() }
            Button("Retry") { Task { await load() } }
        } message: { Text(verbatim: $0.message) }
        .alert(Text(verbatim: message?.title ?? ""), isPresented: isPresented($message), presenting: message) { msg in
            Button("OK", role: .cancel) { if msg.closeAfter { close() } }
        } message: { Text(verbatim: $0.text) }
        .alert("Channel saved", isPresented: isPresented($savedPrompt), presenting: savedPrompt) { target in
            Button("Later", role: .cancel) { close() }
            Button("Send test") { sendTest(id: target.id, closeAfter: true) }
        } message: { Text("Send a test notification to “\($0.name)” now?") }
        .alert("Delete channel?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { if let channel { delete(channel.id) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text(deleteText) }
        .sheet(item: $verify) { target in
            ChannelVerifySheet(channelId: target.id, name: target.name,
                               onVerified: { verified(target) },
                               onLater: { if target.justCreated { close() } })
        }
    }

    private var form: some View {
        Form {
            if awaitingVerification, let channel {
                Section {
                    Text("Not verified").font(.headline).foregroundStyle(.orange)
                    Text("This channel won't receive notifications and can't be tested until it is verified.")
                    Button("Verify now", systemImage: "checkmark.shield") {
                        verify = VerifyTarget(id: channel.id, name: ChannelLogic.displayName(channel), justCreated: false)
                    }
                }
            }
            typeSection
            ChannelGeneralSection(name: $name, enabled: $enabled, isDefault: $isDefault, notifyDown: $notifyDown,
                                  notifyUp: $notifyUp, lang: $lang, showValidation: showValidation)
            fieldsSection
            if isEdit, let channel {
                Section {
                    Button("Send test", systemImage: "paperplane") { sendTest(id: channel.id, closeAfter: false) }
                        .disabled(awaitingVerification)
                }
                Section {
                    Button("Delete channel", systemImage: "trash", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(isBusy)
    }

    @ViewBuilder
    private var typeSection: some View {
        Section {
            if isEdit {
                LabeledContent("Type") {
                    HStack(spacing: 6) {
                        Image(systemName: ChannelLogic.systemImage(type: channel?.type?.rawValue)).foregroundStyle(.tint)
                        Text(verbatim: (channel?.typeLabel ?? channel?.type?.rawValue ?? "")
                             + (isThisDevice ? " · " + String(localized: "This device") : ""))
                    }
                }
            } else {
                Picker("Type", selection: $type) {
                    ForEach(types, id: \.self) { entry in
                        Label {
                            if entry.type == .app {
                                Text("IPv64 App (this device)")
                            } else {
                                Text(verbatim: entry.label?.nonBlank ?? entry.type?.rawValue ?? "")
                            }
                        } icon: {
                            Image(systemName: ChannelLogic.systemImage(type: entry.type?.rawValue))
                        }
                        .tag(Optional(entry))
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: type) { old, new in typeChanged(from: old, to: new) }
            }
        }
    }

    @ViewBuilder
    private var fieldsSection: some View {
        if isEdit && type == nil {
            Section(channel?.typeLabel ?? String(localized: "Settings")) {
                Text("The settings of this channel type can only be changed at ipv64.net.")
            }
        } else if !fields.isEmpty || type?.needsVerification == true {
            Section {
                ForEach(fields, id: \.self) { field in
                    let key = field.key ?? ""
                    ChannelFieldRow(field: field, value: binding(key), required: required(field),
                                    error: showValidation ? ChannelLogic.fieldError(field, value: values[key] ?? "", required: required(field)) : nil,
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

    private var deleteText: String {
        guard let channel else { return "" }
        var text = String(localized: "“\(ChannelLogic.displayName(channel))” will be deleted. Checks using only this channel will notify default channels instead.")
        if isThisDevice { text += String(localized: " This device will no longer receive push notifications.") }
        return text
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0; touched.insert(key) })
    }

    private func isPresented<T>(_ value: Binding<T?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }

    private func close() {
        onChanged()
        dismiss()
    }
}

// MARK: - Loading and actions

private extension ChannelFormSheet {
    func load() async {
        loadError = nil
        let client = session.api
        do {
            if let channelId {
                let types = try? await ipv64Retrying { try await client.hc2.channels.types() }
                let channel = try await ipv64Retrying { try await client.hc2.channels.get(channelId) }
                apply(channel, type: types?.first { $0.type == channel.type })
            } else {
                guard !loaded else { return }
                types = try await ipv64Retrying { try await client.hc2.channels.types() }
                let first = types.first { $0.type != .app } ?? types.first
                type = first
                resetFields(for: first, replacing: nil)
                loaded = true
            }
        } catch is CancellationError {
        } catch {
            loadError = ErrorText(error)
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

    func typeChanged(from old: HC2ChannelType?, to new: HC2ChannelType?) {
        if new?.type == .app {
            onPush()
        } else {
            resetFields(for: new, replacing: old)
        }
    }

    /// New type: its defaults; the name follows the type as long as the user did not type their own.
    func resetFields(for type: HC2ChannelType?, replacing old: HC2ChannelType?) {
        if name.isEmpty || name == old?.label { name = type?.label ?? "" }
        values = [:]
        touched = []
        showValidation = false
        for field in type?.fields ?? [] {
            if let key = field.key { values[key] = ChannelLogic.initialValue(field, config: nil, isEdit: false) }
        }
    }

    func save() {
        showValidation = true
        let invalid = fields.contains {
            ChannelLogic.fieldError($0, value: values[$0.key ?? ""] ?? "", required: required($0)) != nil
        }
        guard let trimmed = name.nonBlank?.trimmingCharacters(in: .whitespacesAndNewlines), !invalid else { return }
        let config = ChannelLogic.buildConfig(fields: fields, values: values, touched: touched,
                                              base: channel?.config, isEdit: isEdit, keepKeys: keepKeys)
        if let channelId {
            update(channelId, name: trimmed, config: config)
        } else if let type {
            create(type, name: trimmed, config: config)
        }
    }

    func create(_ type: HC2ChannelType, name: String, config: [String: JSONValue]) {
        let input = HC2ChannelInput(name: name, type: type.type, config: config, enabled: enabled, default: isDefault,
                                    lang: lang, notifyDown: notifyDown, notifyUp: notifyUp)
        let client = session.api
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                let created = try await ipv64Retrying { try await client.hc2.channels.create(input) }
                onChanged()
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

    /// Only changed fields (the name is always carried); nothing changed closes without a request.
    func update(_ id: Int, name: String, config: [String: JSONValue]) {
        guard let base = channel else { return }
        let baseLang = base.lang == .de || base.lang == .en ? base.lang : ChannelLogic.systemLanguage
        let input = HC2ChannelInput(
            name: name,
            config: config != (base.config ?? [:]) ? config : nil,
            enabled: enabled != (base.enabled ?? true) ? enabled : nil,
            default: isDefault != (base.default ?? false) ? isDefault : nil,
            lang: lang != baseLang ? lang : nil,
            notifyDown: notifyDown != (base.notifyDown ?? true) ? notifyDown : nil,
            notifyUp: notifyUp != (base.notifyUp ?? true) ? notifyUp : nil)
        guard name != (base.name ?? "") || input.config != nil || input.enabled != nil || input.default != nil
                || input.lang != nil || input.notifyDown != nil || input.notifyUp != nil else {
            dismiss()
            return
        }
        let client = session.api
        Task {
            isBusy = true
            defer { isBusy = false }
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
            isBusy = true
            defer { isBusy = false }
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

    func delete(_ id: Int) {
        let client = session.api
        let apiKey = session.apiKey
        Task {
            isBusy = true
            defer { isBusy = false }
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
            onChanged()
        }
    }
}

private struct VerifyTarget: Identifiable {
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
