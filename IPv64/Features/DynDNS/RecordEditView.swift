import SwiftUI
import IPv64

/// Record edit (spec 02 A6).
struct RecordEditView: View {
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    let domain: String
    let recordId: String

    @State private var original: Record?
    @State private var type = "A"
    @State private var prefix = ""
    @State private var content = ""
    @State private var busy = false
    @State private var error: ErrorText?

    private var locked: Bool { DynDNSLogic.isLocked(original?.state) }
    private var trimmedContent: String { content.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPrefix: String { prefix.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var typeChanged: Bool { type != original?.type?.rawValue }
    private var prefixChanged: Bool { trimmedPrefix != DynDNSLogic.editPrefix(original?.prefix) }
    private var contentChanged: Bool { trimmedContent != original?.content }
    private var isIpType: Bool { original?.type == .a || original?.type == .aaaa }
    private var replaces: Bool { typeChanged || prefixChanged || (contentChanged && !isIpType) }

    var body: some View {
        Group {
            if recordId.isEmpty {
                ContentUnavailableView("No record selected.", systemImage: "list.bullet")
            } else if let original {
                form(original)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Edit record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if busy {
                    ProgressView()
                } else {
                    Button("Save", systemImage: "checkmark") { Task { await save() } }
                        .disabled(original == nil || locked || trimmedContent.isEmpty)
                }
            }
        }
        .task { await load() }
        .errorAlert($error) { Task { await load() } }
    }

    private func form(_ record: Record) -> some View {
        Form {
            Section {
                LabeledContent("Name") {
                    Text(verbatim: record.fqdn ?? [record.prefix, record.domain].compactMap { $0?.nonBlank }.joined(separator: "."))
                }
                LabeledContent("TTL", value: "\(record.ttl.map(String.init) ?? "–") s")
                if let label = DynDNSLogic.stateLabel(record.state) { LabeledContent("State", value: label) }
                if record.pendingDNS == true { LabeledContent("DNS", value: "Change is being propagated") }
                if let updated = record.updatedAt { LabeledContent("Last update", value: Formatters.germanTime(updated)) }
            }
            if locked {
                Section("Locked") {
                    Text(verbatim: DynDNSLogic.lockReason(record.state) ?? String(localized: "This record cannot be edited."))
                }
            }
            Section {
                Picker("Type", selection: $type) {
                    ForEach(typeOptions, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                .disabled(locked)
                TextField("Prefix", text: $prefix, prompt: Text("e.g. www"))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: prefix) { prefix = prefix.trimmingCharacters(in: .whitespaces) }
                    .disabled(locked)
                TextField("Value", text: $content, prompt: Text("e.g. IP, TXT record, MX \"10 mail.example.com\""),
                          axis: type == "TXT" ? .vertical : .horizontal)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .disabled(locked)
                if trimmedContent.isEmpty { Text("Required").font(.caption).foregroundStyle(Color.ipv64Red) }
            } header: {
                Text("Record")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Empty = the domain itself")
                    if !locked {
                        Text(replaces
                             ? "This change replaces the record: it gets a new ID and record token. Scripts that use the old record token must be updated."
                             : "Changing only the IP of an A/AAAA record keeps its ID and record token. Any other change replaces the record with a new ID and token.")
                    }
                }
            }
        }
        .disabled(busy)
    }

    private var typeOptions: [String] {
        let current = original?.type?.rawValue
        return DynDNSLogic.allRecordTypes + (current.map { DynDNSLogic.allRecordTypes.contains($0) ? [] : [$0] } ?? [])
    }

    private func load() async {
        guard !recordId.isEmpty else { return }
        do {
            let record: Record
            if let cached = DomainCache.get(domain, revision: session.accountRevision)?.records?
                .first(where: { String($0.id) == recordId }) {
                record = cached
            } else {
                record = try await ipv64Retrying { try await session.api.records.get(recordId) }
            }
            guard original == nil else { return }
            original = record
            type = record.type?.rawValue ?? "A"
            prefix = DynDNSLogic.editPrefix(record.prefix)
            content = record.content ?? ""
        } catch {
            if !Task.isCancelled { self.error = ErrorText(error) }
        }
    }

    private func save() async {
        guard let original else { return }
        guard typeChanged || prefixChanged || contentChanged else {
            router.pop()
            return
        }
        busy = true
        defer { busy = false }
        do {
            _ = try await ipv64Retrying {
                try await session.api.records.update(
                    recordId, type: typeChanged ? RecordType(rawValue: type) : nil,
                    prefix: prefixChanged ? trimmedPrefix : nil, content: contentChanged ? trimmedContent : nil)
            }
            DomainCache.invalidate(domain)
            if let d = original.domain { DomainCache.invalidate(d) }
            router.pop()
            router.reload()
        } catch {
            if !Task.isCancelled { self.error = ErrorText(error) }
        }
    }
}
