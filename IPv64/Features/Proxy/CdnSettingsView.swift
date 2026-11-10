import SwiftUI
import IPv64

/// Cloud CDN settings (spec 03 §10.2). Saves only the fields that changed.
struct CdnSettingsView: View {
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    let token: String

    @State private var original: CDNDomainDetail?
    @State private var initial: CdnForm?
    @State private var form: CdnForm?
    @State private var notAvailable: String?
    @State private var errors = CdnForm.Errors()
    @State private var busy: LocalizedStringKey?
    @State private var error: ErrorText?

    var body: some View {
        Group {
            if let form = Binding($form), let original {
                CdnSettingsForm(form: form, errors: $errors, domain: original.displayName,
                                proxyOn: original.proxy?.state == .on)
            }
        }
        .navigationTitle("CDN settings")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if let notAvailable { NotAvailableView(feature: "CDN", reason: notAvailable) }
            else if form == nil { LoadingView() }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save", systemImage: "checkmark") { Task { await save() } }
                    .disabled(busy != nil || notAvailable != nil || form == nil)
            }
        }
        .loadingOverlay(busy != nil, text: busy ?? "")
        .errorAlert($error) { Task { await load() } }
        .task { await load() }
    }

    private func load() async {
        notAvailable = nil
        do {
            let detail = try await ipv64Retrying { try await session.api.cdn.get(token) }
            original = detail
            initial = CdnForm(detail)
            form = CdnForm(detail)
        } catch {
            if let e = error as? IPv64Error, e.isPlanRestricted { notAvailable = e.planRestrictionText }
            else if !isCancellation(error) { self.error = ErrorText(error) }
        }
    }

    private func save() async {
        guard let initial, let form else { return }
        let result = form.diff(from: initial)
        errors = result.errors
        guard !result.errors.hasAny else { return }
        guard let request = result.request else {
            router.pop()
            return
        }
        busy = "Saving..."
        defer { busy = nil }
        do {
            _ = try await ipv64Retrying {
                try await session.api.cdn.update(
                    token, frontend: request.frontend, backendScheme: request.scheme, backendPort: request.port,
                    websocket: request.websocket, caching: request.caching, accessList: request.accessList)
            }
            router.reload()
            router.pop()
        } catch {
            if !isCancellation(error) { self.error = ErrorText(error, context: .update) }
        }
    }
}

private struct CdnSettingsForm: View {
    @Binding var form: CdnForm
    @Binding var errors: CdnForm.Errors
    let domain: String
    let proxyOn: Bool

    var body: some View {
        Form {
            Section { Text(verbatim: domain).font(.headline) }
            Section {
                Picker("Frontend", selection: $form.frontend) {
                    ForEach(CDNFrontend.all, id: \.self) { Text(verbatim: $0.label) }
                }
            } header: { Text("Visitors") } footer: { Text(verbatim: form.frontend.hint) }
            Section {
                Picker("Protocol", selection: $form.scheme) {
                    ForEach(CDNBackendScheme.all, id: \.self) { Text(verbatim: $0.label) }
                }
                LabeledContent("Port") {
                    TextField("", text: $form.port).multilineTextAlignment(.trailing).keyboardType(.numberPad)
                        .onChange(of: form.port) { errors.port = nil }
                }
                if let port = errors.port { ErrorLine(port) }
                Toggle("WebSocket", isOn: $form.websocket).disabled(!(proxyOn || form.websocket))
            } header: { Text("Your server") } footer: {
                Text(proxyOn ? "Allows WebSocket connections through the proxy." : "Only available while the reverse proxy is switched on.")
            }
            Section {
                Toggle("Cache responses", isOn: $form.cacheEnabled)
                if form.cacheEnabled {
                    LabeledContent("Cache duration (minutes)") {
                        TextField("", text: $form.cacheMinutes).multilineTextAlignment(.trailing).keyboardType(.numberPad)
                            .onChange(of: form.cacheMinutes) { errors.time = nil }
                    }
                    ErrorLine(errors.time ?? String(localized: "1 to 600 minutes."), isError: errors.time != nil)
                    LabeledContent("Cache size (MB)") {
                        TextField("", text: $form.cacheSizeMB).multilineTextAlignment(.trailing).keyboardType(.numberPad)
                            .onChange(of: form.cacheSizeMB) { errors.size = nil }
                    }
                    ErrorLine(errors.size ?? String(localized: "At least 1 MB, up to the limit of your plan."), isError: errors.size != nil)
                }
            } header: { Text("Cache") }
            Section {
                Toggle("Use access list", isOn: $form.aclEnabled)
                if form.aclEnabled {
                    Picker("Mode", selection: $form.aclMode) {
                        ForEach(CDNAccessListMode.all, id: \.self) { Text(verbatim: $0.label) }
                    }
                }
            } header: { Text("Access list") } footer: {
                if form.aclEnabled && form.aclMode == .allowlist {
                    Text("Entries are managed on the CDN page. Only listed addresses can reach this site: make sure your own address is in the list.")
                } else {
                    Text("Entries are managed on the CDN page.")
                }
            }
        }
    }
}

private struct ErrorLine: View {
    let text: String
    var isError = true

    init(_ text: String, isError: Bool = true) {
        self.text = text
        self.isError = isError
    }

    var body: some View {
        Text(verbatim: text).font(.footnote).foregroundStyle(isError ? Color.ipv64Red : .secondary)
    }
}
