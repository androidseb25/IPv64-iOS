import SwiftUI
import IPv64

/// New domain (spec 02 A2).
struct DomainNewSheet: View {
    @Environment(Session.self) private var session
    let onCreated: () -> Void

    @State private var subdomain = ""
    @State private var zone = "ipv64.net"
    @State private var busy = false
    @State private var error: ErrorText?

    var body: some View {
        DynDNSSheet(title: "New domain", confirmLabel: "Create",
                    confirmEnabled: !subdomain.trimmingCharacters(in: .whitespaces).isEmpty, isBusy: busy,
                    onConfirm: { Task { await create() } }) {
            Section {
                TextField("Subdomain", text: $subdomain, prompt: Text("homelab01"))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("Domain", selection: $zone) {
                    ForEach(DynDNSLogic.zones.dropLast(), id: \.self) { Text(verbatim: $0).tag($0) }
                }
            }
        }
        .errorAlert($error)
        .presentationDetents([.medium])
    }

    private func create() async {
        let sub = subdomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard DynDNSLogic.isValidSubdomain(sub) else {
            error = ErrorText(title: String(localized: "Invalid subdomain"),
                              message: String(localized: "Enter a single label without dots or spaces, e.g. homelab01."))
            return
        }
        busy = true
        defer { busy = false }
        do {
            _ = try await session.api.domains.create(name: "\(sub).\(zone)")
            onCreated()
        } catch {
            self.error = ErrorText(error, context: .create)
        }
    }
}

/// New DNS record (spec 02 A5).
struct RecordNewSheet: View {
    @Environment(Session.self) private var session
    let domain: String
    let onCreated: () -> Void

    @State private var prefix = ""
    @State private var type = "A"
    @State private var value = ""
    @State private var busy = false
    @State private var error: ErrorText?

    var body: some View {
        DynDNSSheet(title: "New DNS record", subtitle: domain, confirmLabel: "Create",
                    confirmEnabled: !value.trimmingCharacters(in: .whitespaces).isEmpty, isBusy: busy,
                    onConfirm: { Task { await create() } }) {
            Section {
                TextField("Name", text: $prefix, prompt: Text("dkim._domainkey"))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("Type", selection: $type) {
                    ForEach(DynDNSLogic.newRecordTypes, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                TextField("Value", text: $value, prompt: Text("IP or TXT content"))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            } footer: {
                Text("Empty = the domain itself")
            }
        }
        .errorAlert($error)
        .presentationDetents([.medium])
    }

    private func create() async {
        let prefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            error = ErrorText(title: String(localized: "Empty field"),
                              message: String(localized: "Please fill the DNS value field!"))
            return
        }
        busy = true
        defer { busy = false }
        do {
            _ = try await session.api.records.create(domain: domain, type: RecordType(rawValue: type),
                                                     prefix: prefix.isEmpty ? nil : prefix, content: value)
            DomainCache.invalidate(domain)
            onCreated()
        } catch {
            self.error = ErrorText(error)
        }
    }
}
