import SwiftUI
import IPv64

/// "Route through CDN": mode choice for one record (checkmark rows).
struct CdnEnableRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: Record
    let onConfirm: (CDNRecordMode) -> Void

    @State private var mode = CDNRecordMode.full

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(CDNRecordMode.all, id: \.self) { option in
                        Button { mode = option } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: mode == option ? "checkmark" : "").frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: option.title).foregroundStyle(.primary)
                                    Text(verbatim: option.detail).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(mode == option ? .isSelected : [])
                    }
                } header: {
                    Text(verbatim: record.cdnTitle)
                } footer: {
                    Text("The DNS entry changes immediately. Visitors reach the CDN as soon as DNS caches expire.")
                }
            }
            .navigationTitle("Route through CDN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enable", systemImage: "checkmark") { dismiss(); onConfirm(mode) }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// "Add to access list": IP or CIDR with inline validation.
struct CdnAddAddressSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (String) -> Void

    @State private var address = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("203.0.113.0/24", text: $address)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.numbersAndPunctuation)
                        .onChange(of: address) { error = nil }
                } header: {
                    Text("IP address or network")
                } footer: {
                    if let error { Text(verbatim: String(localized: String.LocalizationValue(error))).foregroundStyle(Color.ipv64Red) }
                    else { Text("IPv4 or IPv6, optionally with prefix length (CIDR).") }
                }
            }
            .navigationTitle("Add to access list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add", systemImage: "plus", action: submit) }
            }
        }
        .presentationDetents([.medium])
    }

    private func submit() {
        if let problem = ProxyLogic.addressError(address) { error = problem; return }
        dismiss()
        onConfirm(address.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// Parameters of a new port mapping.
struct CdnMappingInput {
    let record: String
    let targetPort: Int
    let transport: CDNTransport
    let name: String?
    let listenPort: Int?
}

/// "Add port mapping" for records that run through the CDN.
struct CdnMappingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let records: [Record]
    let onConfirm: (CdnMappingInput) -> Void

    @State private var record: Record?
    @State private var targetPort = ""
    @State private var listenPort = ""
    @State private var name = ""
    @State private var transport = CDNTransport.tcp
    @State private var targetError: String?
    @State private var listenError: String?

    private static let listenRange = 50000...62000

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Forwards a public port of the CDN server to a port on your server.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Picker("Target record", selection: $record) {
                        ForEach(records) { Text(verbatim: $0.cdnTitle).tag(Optional($0)) }
                    }
                    LabeledContent("Port on your server") {
                        TextField("", text: $targetPort).multilineTextAlignment(.trailing).keyboardType(.numberPad)
                            .onChange(of: targetPort) { targetError = nil }
                    }
                    if let targetError { Text(verbatim: targetError).font(.footnote).foregroundStyle(Color.ipv64Red) }
                    Picker("Protocol", selection: $transport) {
                        ForEach(CDNTransport.all, id: \.self) { Text(verbatim: $0.label) }
                    }
                } header: { Text("Target") }
                Section {
                    LabeledContent("Public port (optional)") {
                        TextField("", text: $listenPort).multilineTextAlignment(.trailing).keyboardType(.numberPad)
                            .onChange(of: listenPort) { listenError = nil }
                    }
                    if let listenError { Text(verbatim: listenError).font(.footnote).foregroundStyle(Color.ipv64Red) }
                    LabeledContent("Name (optional)") {
                        TextField("", text: $name).multilineTextAlignment(.trailing)
                    }
                } header: { Text("Optional") } footer: {
                    Text("50000-62000. A free port is assigned if empty.")
                }
            }
            .navigationTitle("Add port mapping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add", systemImage: "plus", action: submit) }
            }
            .onAppear { if record == nil { record = records.first } }
        }
        .presentationDetents([.large])
    }

    private func submit() {
        guard let target = ProxyLogic.parsePort(targetPort) else {
            targetError = String(localized: "Enter a port between 1 and 65535.")
            return
        }
        var listen: Int?
        if !listenPort.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let port = ProxyLogic.parsePort(listenPort, range: Self.listenRange) else {
                listenError = String(localized: "Enter a port between 50000 and 62000 or leave it empty.")
                return
            }
            listen = port
        }
        guard let record else { return }
        dismiss()
        onConfirm(CdnMappingInput(record: String(record.id), targetPort: target, transport: transport,
                                  name: name.trimmingCharacters(in: .whitespaces).nonBlank, listenPort: listen))
    }
}
