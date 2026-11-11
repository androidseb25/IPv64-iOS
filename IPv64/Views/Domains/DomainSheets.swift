import SwiftUI
import IPv64

/// A form sheet: Cancel leading, confirm trailing, locked while busy.
struct DynDNSSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    var subtitle: String?
    var confirmLabel: LocalizedStringKey?
    var confirmEnabled = true
    var isBusy = false
    var onConfirm: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            Form {
                if let subtitle { Section { Text(verbatim: subtitle).foregroundStyle(.secondary) } }
                content
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if confirmLabel == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") { dismiss() }
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark") { dismiss() }.disabled(isBusy)
                    }
                }
                if let onConfirm, let confirmLabel {
                    ToolbarItem(placement: .confirmationAction) {
                        if isBusy {
                            ProgressView()
                        } else {
                            Button(confirmLabel, systemImage: "checkmark", action: onConfirm).disabled(!confirmEnabled)
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isBusy)
    }
}

/// Manual DynDNS update (spec 02 A4): form, then the result in the same sheet.
struct DomainDynDnsSheet: View {
    @Environment(Session.self) private var session
    let domain: String
    /// Called when the sheet closes after a successful update.
    let onUpdated: () -> Void

    @State private var ipv4 = ""
    @State private var ipv6 = ""
    @State private var prefix = ""
    @State private var loadingFamily: Session.IPFamilyChoice?
    @State private var hint: LocalizedStringKey?
    @State private var busy = false
    @State private var result: DynDNSResult?
    @State private var error: ErrorText?

    private var v4Error: Bool { !ipv4.isEmpty && !DynDNSLogic.isIpv4(ipv4) }
    private var v6Error: Bool { !ipv6.isEmpty && !DynDNSLogic.isIpv6(ipv6) }

    var body: some View {
        Group {
            if let result {
                resultView(result)
            } else {
                form
            }
        }
        .errorAlert($error)
        .presentationDetents([.large])
    }

    private var form: some View {
        DynDNSSheet(title: "Manual DynDNS update", confirmLabel: "Update",
                    confirmEnabled: !v4Error && !v6Error, isBusy: busy, onConfirm: { Task { await update() } }) {
            Section {
                Text("Sets the A/AAAA records of \(domain). Leave both addresses empty to use the address the request comes from. Only public addresses are accepted; missing records are created.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Addresses") {
                field("IPv4 address", prompt: "e.g. 203.0.113.10", text: $ipv4, invalid: v4Error,
                      message: "Not a valid IPv4 address")
                field("IPv6 address", prompt: "e.g. 2001:db8::10", text: $ipv6, invalid: v6Error,
                      message: "Not a valid IPv6 address")
                HStack {
                    fill("My IPv4", family: .v4)
                    fill("My IPv6", family: .v6)
                }
                .buttonStyle(.bordered)
                if let hint { Text(hint).font(.footnote).foregroundStyle(.orange) }
            }
            Section {
                TextField("Prefix (optional)", text: $prefix, prompt: Text("e.g. nas"))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: prefix) { prefix = prefix.trimmingCharacters(in: .whitespaces) }
            } header: {
                Text("Record")
            } footer: {
                Text("Empty = the domain itself")
            }
        }
    }

    private func field(_ title: LocalizedStringKey, prompt: LocalizedStringKey, text: Binding<String>,
                       invalid: Bool, message: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: text, prompt: Text(prompt))
                .keyboardType(.asciiCapable).textInputAutocapitalization(.never).autocorrectionDisabled()
                .onChange(of: text.wrappedValue) { text.wrappedValue = text.wrappedValue.trimmingCharacters(in: .whitespaces) }
            if invalid { Text(message).font(.caption).foregroundStyle(.red) }
        }
    }

    private func fill(_ title: LocalizedStringKey, family: Session.IPFamilyChoice) -> some View {
        Button {
            Task { await fillMyIP(family) }
        } label: {
            HStack(spacing: 6) {
                if loadingFamily == family { ProgressView().controlSize(.small) }
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(loadingFamily == family)
    }

    private func resultView(_ result: DynDNSResult) -> some View {
        DynDNSSheet(title: "DynDNS update") {
            Section {
                Text(result.changed == true ? "At least one record was changed." : "No record was changed.")
                if (result.results ?? []).isEmpty {
                    Text("The server returned no results per IP.").foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(Array((result.results ?? []).enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: entry.type?.rawValue ?? "?").font(.headline).frame(minWidth: 56, alignment: .leading)
                        VStack(alignment: .leading) {
                            Text(verbatim: entry.ip ?? "–").font(.body.monospaced())
                            Text(verbatim: DynDNSLogic.outcomeLabel(entry.result))
                                .font(.caption)
                                .foregroundStyle(DynDNSLogic.isFailure(entry.result) ? .red : Color.secondary)
                        }
                    }
                }
            }
        }
        .onDisappear(perform: onUpdated)
    }

    private func fillMyIP(_ family: Session.IPFamilyChoice) async {
        hint = nil
        loadingFamily = family
        defer { loadingFamily = nil }
        if let ip = await session.myIP(family) {
            if family == .v4 { ipv4 = ip } else { ipv6 = ip }
        } else {
            hint = family == .v4 ? "No public IPv4 address found." : "No public IPv6 address found."
        }
    }

    private func update() async {
        busy = true
        defer { busy = false }
        do {
            let r = try await session.api.domains.updateDynDNS(
                domain, ipv4: ipv4.nonBlank, ipv6: ipv6.nonBlank, prefix: prefix.nonBlank)
            result = r
        } catch {
            self.error = ErrorText(error)
        }
    }
}

/// Shown after "Rotate update token" (spec 02 A3 RotatedTokenDialog): the URL stays in memory only.
struct RotatedTokenSheet: View {
    let url: String

    var body: some View {
        DynDNSSheet(title: "New update URL") {
            Section {
                Text("The update token was rotated. The old update URL no longer works. Enter the new URL in your router or update script.")
            }
            Section("Update URL") {
                Text(verbatim: url).font(.callout.monospaced())
                Button("Copy update URL", systemImage: "doc.on.doc") {
                    Clipboard.copy(url, sensitive: true)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

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
            self.error = ErrorText(error)
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
            onCreated()
        } catch {
            self.error = ErrorText(error)
        }
    }
}
