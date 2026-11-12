import SwiftUI
import IPv64

/// First section: type, name and target.
struct HealthcheckCheckSection: View {
    @Binding var f: HealthcheckFormState
    let editing: Bool
    var error: String?

    var body: some View {
        Section {
            if editing {
                LabeledContent("Type") { Label(f.type.label, systemImage: f.type.symbol) }
            } else {
                Picker("Type", selection: typeBinding) {
                    ForEach(healthcheckCreateTypes, id: \.self) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
                .pickerStyle(.navigationLink)
            }
            TextField("Name", text: $f.name)
            if f.type != .push {
                TextField(f.type.targetHint, text: $f.target)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
        } footer: {
            HcFooter(hint: f.type == .push && !editing ? "A push URL is created with the check." : nil, error: error)
        }
    }

    /// Selecting a new type resets the parameters.
    private var typeBinding: Binding<HC2CheckType> {
        Binding(get: { f.type }, set: { type in
            guard type != f.type else { return }
            f.type = type
            f.ps = ParamsState.initial(type)
            f.iniPs = f.ps
        })
    }
}

/// Where the check runs: online, on a node or both; node and locations.
struct HealthcheckExecutionSection: View {
    @Binding var f: HealthcheckFormState
    let editing: Bool
    let nodes: [HC2Node]
    let account: HC2Account?
    let detail: HC2CheckDetail?
    var error: String?

    private var maxLocations: Int? {
        guard let n = account?.locationsPerCheck, n > 0 else { return nil }
        return n
    }

    private var locationSummary: String {
        let names = f.locations.map { code in
            account?.locations?.first { $0.code == code }?.name?.nonBlank ?? code
        }
        switch names.count {
        case 0: return String(localized: "None")
        case 1: return names[0]
        default: return String(localized: "\(names.count) locations")
        }
    }

    var body: some View {
        if f.type != .push {
            Section {
                if !nodes.isEmpty || !f.online {
                    Picker("Where it runs", selection: execBinding) {
                        Text("Online").tag(HC2Execution.online)
                        Text("Node").tag(HC2Execution.local)
                        Text("Online + node").tag(HC2Execution.both)
                    }
                    .pickerStyle(.segmented)
                }
                if !f.online {
                    Picker("Node", selection: $f.nodeId) {
                        Text("Select a node").tag(String?.none)
                        ForEach(nodeOptions, id: \.id) { Text(verbatim: $0.label).tag(Optional($0.id)) }
                    }
                    .pickerStyle(.navigationLink)
                }
                if f.usesLocations {
                    NavigationLink {
                        HealthcheckLocationList(selected: $f.locations, locations: account?.locations ?? [],
                                                limit: maxLocations)
                    } label: {
                        LabeledContent("Locations") { Text(verbatim: locationSummary) }
                    }
                }
            } header: {
                Text("Execution")
            } footer: {
                HcFooter(hint: editing ? "Changing where the check runs or its locations runs a test measurement first." : nil,
                         error: error)
            }
        }
    }

    private var execBinding: Binding<HC2Execution> {
        Binding(get: { f.execSel }, set: { value in
            f.execSel = value
            if value != .online && f.nodeId == nil && nodes.count == 1 { f.nodeId = nodes.first?.nodeID }
        })
    }

    private var nodeOptions: [(id: String, label: String)] {
        var list = nodes.map { node -> (String, String) in
            let name = node.name?.nonBlank ?? node.nodeID
            switch node.online {
            case true: return (node.nodeID, "\(name) (\(String(localized: "online")))")
            case false: return (node.nodeID, "\(name) (\(String(localized: "offline")))")
            default: return (node.nodeID, name)
            }
        }
        if let current = f.nodeId, !list.contains(where: { $0.0 == current }) {
            list.append((current, detail?.nodeName?.nonBlank ?? current))
        }
        return list.map { (id: $0.0, label: $0.1) }
    }
}

/// Pushed checkmark list of the measuring locations.
private struct HealthcheckLocationList: View {
    @Binding var selected: [String]
    let locations: [HC2Account.Location]
    let limit: Int?

    var body: some View {
        List {
            Section {
                ForEach(locations, id: \.code) { location in
                    if let code = location.code {
                        Button {
                            toggle(code)
                        } label: {
                            HStack {
                                Text(verbatim: location.name?.nonBlank ?? code)
                                Spacer()
                                if selected.contains(code) { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                            }
                            .contentShape(Rectangle())
                        }
                        .tint(.primary)
                        .accessibilityAddTraits(selected.contains(code) ? .isSelected : [])
                    }
                }
            } footer: {
                if let limit { Text("Locations (up to \(limit))") }
            }
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ code: String) {
        if selected.contains(code) {
            selected.removeAll { $0 == code }
        } else if limit.map({ selected.count < $0 }) ?? true {
            selected.append(code)
        }
    }
}
