import SwiftUI
import IPv64

/// "Check" section: type, name, target, essential parameters.
struct HealthcheckCheckSection: View {
    @Binding var f: HealthcheckFormState
    let editing: Bool

    var body: some View {
        Section("Check") {
            if editing {
                LabeledContent("Type", value: f.type.label)
            } else {
                Picker("Type", selection: typeBinding) {
                    ForEach(healthcheckCreateTypes, id: \.self) { Text(verbatim: $0.label).tag($0) }
                }
            }
            HcField(label: "Name", text: $f.name)
            if f.type != .push {
                HcField(label: "Target", text: $f.target, kind: .url, prompt: f.type.targetHint)
            } else if !editing {
                Text("A push URL is created with the check.").font(.caption).foregroundStyle(.secondary)
            }
            HealthcheckEssentialParams(s: $f.ps, type: f.type)
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

/// "Execution" section: where it runs, node, locations.
struct HealthcheckExecutionSection: View {
    @Binding var f: HealthcheckFormState
    let editing: Bool
    let nodes: [HC2Node]
    let account: HC2Account?
    let detail: HC2CheckDetail?

    private var maxLocations: Int? {
        guard let n = account?.locationsPerCheck, n > 0 else { return nil }
        return n
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
                }
                if !f.online {
                    Picker("Node", selection: $f.nodeId) {
                        Text("Select a node").tag(String?.none)
                        ForEach(nodeOptions, id: \.id) { Text(verbatim: $0.label).tag(Optional($0.id)) }
                    }
                }
                if f.usesLocations {
                    locations
                }
                if editing {
                    Text("Changing where the check runs or its locations runs a test measurement first.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: { Text("Execution") }
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

    @ViewBuilder
    private var locations: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(maxLocations.map { "\(String(localized: "Locations")) (\(String(localized: "up to \($0)")))" }
                 ?? String(localized: "Locations"))
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(account?.locations ?? [], id: \.code) { location in
                if let code = location.code {
                    Toggle(location.name?.nonBlank ?? code, isOn: Binding(
                        get: { f.locations.contains(code) },
                        set: { on in
                            if on {
                                if maxLocations.map({ f.locations.count < $0 }) ?? true { f.locations.append(code) }
                            } else {
                                f.locations.removeAll { $0 == code }
                            }
                        }))
                }
            }
        }
    }
}

/// Collapsible "Advanced" group: type options, schedule, tolerance.
struct HealthcheckAdvancedSection: View {
    @Binding var f: HealthcheckFormState
    @Binding var expanded: Bool
    let editing: Bool
    let detail: HC2CheckDetail?

    private var ipModes: [HC2IPMode?] {
        [nil, .auto, .ipv4, .ipv6, .both].filter { !(editing && detail?.ipMode != nil && $0 == nil) }
    }

    private var policies: [HC2Policy?] {
        [nil, .all, .any, .majority].filter { !(editing && detail?.policy != nil && $0 == nil) }
    }

    private func policyLabel(_ policy: HC2Policy?) -> String {
        let unit = f.execution == .both ? String(localized: "sources") : String(localized: "locations")
        switch policy {
        case .all: return String(localized: "Down if all \(unit) fail")
        case .any: return String(localized: "Down if any of the \(unit) fails")
        case .majority: return String(localized: "Down if most \(unit) fail")
        default: return String(localized: "Default")
        }
    }

    var body: some View {
        Section {
            DisclosureGroup("Advanced", isExpanded: $expanded) {
                if f.type.hasAdvancedParams {
                    Text("\(f.type.label) options").font(.subheadline.weight(.semibold))
                    HealthcheckAdvancedParams(s: $f.ps, type: f.type, ini: f.iniPs, editing: editing, online: f.online)
                }
                Text("Schedule").font(.subheadline.weight(.semibold))
                Text(editing ? "Clearing a field keeps the current value; it cannot be reset to the default here."
                             : "Empty fields use the server default.")
                    .font(.caption).foregroundStyle(.secondary)
                HcDurationField(label: "Interval", value: $f.intervalValue, unit: $f.intervalUnit, footer: "Minimum 20 seconds")
                HcDurationField(label: "Retry interval", value: $f.retryValue, unit: $f.retryUnit, footer: "Minimum 5 seconds")
                HcField(label: "Retries (0-10)", text: $f.retries, kind: .number)
                HcField(label: "Timeout (seconds)", text: $f.timeout, kind: .decimal)
                HcField(label: "Connect timeout (seconds)", text: $f.connectTimeout, kind: .decimal)
                HcField(label: "Stabilize (1-20)", text: $f.stabilize, kind: .number,
                        footer: "Measurements until the state changes")
                HcToggle(label: "Invert result", isOn: $f.invert)
                Picker("IP mode", selection: $f.ipMode) {
                    ForEach(ipModes, id: \.self) { Text(verbatim: $0?.rawValue ?? String(localized: "Default")).tag($0) }
                }
                if f.type != .push && f.policyApplies {
                    Picker("Overall rule", selection: $f.policy) {
                        ForEach(policies, id: \.self) { Text(verbatim: policyLabel($0)).tag($0) }
                    }
                }
            }
        }
    }
}

/// Collapsible "Notifications & organisation" group.
struct HealthcheckNotificationsSection: View {
    @Binding var f: HealthcheckFormState
    @Binding var expanded: Bool
    let editing: Bool
    let detail: HC2CheckDetail?
    let channels: [HC2Channel]
    let channelTypes: [HC2ChannelType]?

    var body: some View {
        Section {
            DisclosureGroup("Notifications & organisation", isExpanded: $expanded) {
                Text("Notifications").font(.subheadline.weight(.semibold))
                HcToggle(label: "Notify when down", isOn: $f.notifyDown)
                HcToggle(label: "Notify when back up", isOn: $f.notifyUp)
                HcToggle(label: "Notify when degraded", isOn: $f.notifyDegraded, footer: "Also notify on partial failure")
                HcToggle(label: "Critical", isOn: $f.critical, footer: "Ignores quiet hours")
                HcRepeatPicker(minutes: $f.repeatMinutes, allowsDefault: !(editing && detail?.repeatMinutes != nil))
                Text("Channels").font(.subheadline.weight(.semibold))
                HealthcheckChannelPicker(useDefault: $f.useDefaultChannels, selected: $f.channels,
                                         channels: channels, types: channelTypes)
                Text("Organisation").font(.subheadline.weight(.semibold))
                HcField(label: "Tags", text: $f.tags, footer: "Comma-separated")
                HcField(label: "Group", text: $f.group)
                HcField(label: "Description", text: $f.description, multiline: true)
                if !editing {
                    HcToggle(label: "Create paused", isOn: $f.createPaused,
                             footer: "No measurements until you resume the check")
                }
            }
        }
    }
}
