import SwiftUI
import IPv64

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
                if let hint { Text(hint).font(.footnote).foregroundStyle(Color.ipv64Orange) }
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
            if invalid { Text(message).font(.caption).foregroundStyle(Color.ipv64Red) }
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
                                .foregroundStyle(DynDNSLogic.isFailure(entry.result) ? Color.ipv64Red : Color.secondary)
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
            DomainCache.invalidate(domain)
            result = r
        } catch {
            self.error = ErrorText(error, context: .update)
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
                SecureContainer { Text(verbatim: url).font(.callout.monospaced()).textSelection(.disabled) }
                Button("Copy update URL", systemImage: "doc.on.doc") { Clipboard.copy(url, sensitive: true) }
            }
        }
        .privacyProtected()
        .presentationDetents([.medium])
    }
}
