import SwiftUI
import IPv64

/// Domain settings (spec 02 A7).
struct DomainSettingsView: View {
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    let name: String

    @State private var original: DomainDetail?
    @State private var wildcard = false
    @State private var ignore = DomainIgnore.none
    @State private var prefix = ""
    @State private var busy = false
    @State private var error: ErrorText?

    private var prefixValid: Bool { DynDNSLogic.isValidIpv6Prefix(prefix) }

    var body: some View {
        Group {
            if name.isEmpty {
                ContentUnavailableView("No domain selected.", systemImage: "network")
            } else if original == nil {
                LoadingView()
            } else {
                form
            }
        }
        .navigationTitle("Domain settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if busy {
                    ProgressView()
                } else {
                    Button("Save", systemImage: "checkmark") { Task { await save() } }
                        .disabled(original == nil || !prefixValid)
                }
            }
        }
        .task { await load() }
        .errorAlert($error) { Task { await load() } }
    }

    private var form: some View {
        Form {
            Section { Text(verbatim: name) }
            Section {
                Toggle("Wildcard records", isOn: $wildcard)
            } header: {
                Text("Wildcard")
            } footer: {
                Text("Also resolve *.\(name) to the records of the domain.")
            }
            Section {
                Picker("Ignored address family", selection: $ignore) {
                    Text("None").tag(DomainIgnore.none)
                    Text("Ignore IPv4").tag(DomainIgnore.ipv4)
                    Text("Ignore IPv6").tag(DomainIgnore.ipv6)
                }
            } header: {
                Text("DynDNS updates")
            } footer: {
                Text("Updates of the ignored family are not applied (e.g. ignore IPv6 if your router reports an unwanted address).")
            }
            Section {
                TextField("Fixed IPv6 prefix", text: $prefix, prompt: Text("2001:db8:1234:5600::/56"))
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable)
                    .onChange(of: prefix) { prefix = prefix.trimmingCharacters(in: .whitespaces) }
            } header: {
                Text("IPv6 prefix")
            } footer: {
                if prefixValid {
                    Text("Combined with the interface IDs of your records. Empty = off.")
                } else {
                    Text("Expected e.g. 2001:db8:1234:5600::/56").foregroundStyle(Color.ipv64Red)
                }
            }
        }
        .disabled(busy)
    }

    private func load() async {
        guard !name.isEmpty else { return }
        do {
            let detail: DomainDetail
            if let cached = DomainCache.get(name, revision: session.accountRevision) {
                detail = cached
            } else {
                detail = try await ipv64Retrying { try await session.api.domains.get(name) }
                DomainCache.put(detail, revision: session.accountRevision)
            }
            guard original == nil else { return }
            original = detail
            wildcard = detail.wildcard == true
            ignore = detail.ignore ?? .none
            prefix = detail.ipv6Prefix ?? ""
        } catch {
            if !Task.isCancelled { self.error = ErrorText(error) }
        }
    }

    private func save() async {
        guard let original else { return }
        let newPrefix = prefix.trimmingCharacters(in: .whitespaces)
        let changedWildcard = wildcard != (original.wildcard == true)
        let changedIgnore = ignore != (original.ignore ?? .none)
        let changedPrefix = newPrefix != (original.ipv6Prefix ?? "")
        guard changedWildcard || changedIgnore || changedPrefix else {
            router.pop()
            return
        }
        busy = true
        defer { busy = false }
        do {
            let result = try await ipv64Retrying {
                try await session.api.domains.update(
                    name, wildcard: changedWildcard ? wildcard : nil, ignore: changedIgnore ? ignore : nil,
                    ipv6Prefix: changedPrefix ? newPrefix : nil)
            }
            // The PATCH answer may come without records; the detail then reloads on return.
            DomainCache.invalidate(name)
            if result.records?.isEmpty == false { DomainCache.put(result, revision: session.accountRevision) }
            router.pop()
            router.reload()
        } catch {
            if !Task.isCancelled { self.error = ErrorText(error) }
        }
    }
}
