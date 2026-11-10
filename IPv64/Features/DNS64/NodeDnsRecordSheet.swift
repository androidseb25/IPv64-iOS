import SwiftUI
import IPv64

/// Create/edit form of a local DNS record (spec 03 §9). `onSave` runs after the sheet closed.
struct NodeDnsRecordSheet: View {
    let record: Node64.DNS64Record?
    let onSave: (Node64.DNS64RecordInput) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type = "A"
    @State private var value = ""
    @State private var ttl = ""
    @State private var comment = ""
    @State private var noPTR = false
    @State private var localOnly = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("Type", selection: $type) {
                        ForEach(dns64RecordTypes, id: \.self) { Text(verbatim: $0).tag($0) }
                    }
                    TextField("Value", text: $value).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("TTL (seconds, optional)", text: $ttl).keyboardType(.numberPad)
                    TextField("Comment (optional)", text: $comment)
                }
                Section {
                    if type == "A" || type == "AAAA" {
                        Toggle("No reverse lookup (PTR)", isOn: $noPTR)
                    }
                    Toggle("Only this node", isOn: $localOnly)
                } footer: {
                    Text("Only this node: the record is never synced in a cluster.")
                }
                if record != nil {
                    Section {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            dismiss()
                            onDelete()
                        }
                    }
                }
            }
            .navigationTitle(record == nil ? "New record" : "Edit record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") { save() }
                        .disabled(!dns64RecordValid(name: name, value: value, ttl: ttl))
                }
            }
            .onChange(of: ttl) { ttl = dns64DigitsOnly(ttl) }
        }
        .presentationDetents([.medium, .large])
        .onAppear(perform: fill)
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

    private func save() {
        onSave(Node64.DNS64RecordInput(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: Node64.DNS64RecordType(rawValue: type),
            value: value.trimmingCharacters(in: .whitespacesAndNewlines),
            ttl: Int(ttl),
            comment: dns64Comment(comment, isEdit: record != nil),
            noPTR: dns64Flag(original: record?.noPTR, toggle: noPTR),
            localOnly: dns64Flag(original: record?.localOnly, toggle: localOnly)))
        dismiss()
    }
}
