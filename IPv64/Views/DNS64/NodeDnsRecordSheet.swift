import SwiftUI
import IPv64

/// Create/edit form of a local DNS record. The sheet closes after a successful save or delete.
struct NodeDnsRecordSheet: View {
    let record: Node64.DNS64Record?
    let onSave: (Node64.DNS64RecordInput) async throws -> Void
    let onDelete: () async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type = "A"
    @State private var value = ""
    @State private var ttl = ""
    @State private var comment = ""
    @State private var noPTR = false
    @State private var localOnly = false
    @State private var busy = false
    @State private var confirmDelete = false
    @State private var error: ErrorText?

    private var types: [String] {
        dns64RecordTypes.contains(type) ? dns64RecordTypes : dns64RecordTypes + [type]
    }

    var body: some View {
        DynDNSSheet(title: record == nil ? "New record" : "Edit record", confirmLabel: "Save",
                    confirmEnabled: dns64RecordValid(name: name, value: value, ttl: ttl), isBusy: busy,
                    onConfirm: { run { try await onSave(input) } }) {
            Section {
                TextField("Name", text: $name).textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("Type", selection: $type) {
                    ForEach(types, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                TextField("Value", text: $value).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("TTL (seconds, optional)", text: $ttl).keyboardType(.numberPad)
                TextField("Comment (optional)", text: $comment)
            }
            Section {
                if type == "A" || type == "AAAA" { Toggle("No reverse lookup (PTR)", isOn: $noPTR) }
                Toggle("Only this node", isOn: $localOnly)
            } footer: {
                Text("Only this node: the record is never synced in a cluster.")
            }
            if record != nil {
                Section {
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        .disabled(busy)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear(perform: fill)
        .onChange(of: ttl) { ttl = dns64DigitsOnly(ttl) }
        .alert("Delete record", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { run { try await onDelete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \(name) (\(type))?")
        }
        .errorAlert($error)
    }

    private var input: Node64.DNS64RecordInput {
        Node64.DNS64RecordInput(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: Node64.DNS64RecordType(rawValue: type),
            value: value.trimmingCharacters(in: .whitespacesAndNewlines),
            ttl: Int(ttl),
            comment: dns64Comment(comment, isEdit: record != nil),
            noPTR: dns64Flag(original: record?.noPTR, toggle: noPTR),
            localOnly: dns64Flag(original: record?.localOnly, toggle: localOnly))
    }

    private func fill() {
        guard let record else { return }
        name = record.name
        type = record.type.rawValue
        value = record.value
        ttl = record.ttl.map(String.init) ?? ""
        comment = record.comment ?? ""
        noPTR = record.noPTR ?? false
        localOnly = record.localOnly ?? false
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        Task {
            busy = true
            defer { busy = false }
            do {
                try await operation()
                dismiss()
            } catch { self.error = .node(error) }
        }
    }
}
