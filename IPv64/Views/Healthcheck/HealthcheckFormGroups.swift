import SwiftUI
import IPv64

/// Collapsible "Advanced": type options, schedule, tolerance.
struct HealthcheckAdvancedSection: View {
    @Binding var f: HealthcheckFormState
    @Binding var expanded: Bool
    let editing: Bool
    let detail: HC2CheckDetail?
    var error: String?

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
        HcCollapsibleSection(
            title: "Advanced", isExpanded: $expanded,
            hint: editing ? "Clearing a field keeps the current value; it cannot be reset to the default here."
                          : "Empty fields use the server default.",
            error: error
        ) {
            if f.type.hasAdvancedParams {
                HealthcheckAdvancedParams(s: $f.ps, type: f.type, ini: f.iniPs, editing: editing, online: f.online)
            }
            HcDurationPicker(label: "Interval", value: $f.intervalValue, unit: $f.intervalUnit,
                             presets: [20, 30, 60, 120, 300, 600, 900, 1800, 3600],
                             allowsDefault: !(editing && detail?.intervalSeconds != nil))
            HcDurationPicker(label: "Retry interval", value: $f.retryValue, unit: $f.retryUnit,
                             presets: [5, 10, 30, 60, 120, 300],
                             allowsDefault: !(editing && detail?.retryIntervalSeconds != nil))
            HcStepperRow(label: "Retries", text: $f.retries, range: 0...10)
            HcFieldRow(label: "Timeout", text: $f.timeout, kind: .decimal, prompt: "Default", unit: "s")
            HcFieldRow(label: "Connect timeout", text: $f.connectTimeout, kind: .decimal, prompt: "Default", unit: "s")
            HcStepperRow(label: "Stabilize", text: $f.stabilize, range: 1...20)
            Toggle("Invert result", isOn: $f.invert)
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

/// Collapsible "Notifications & organisation".
struct HealthcheckNotificationsSection: View {
    @Binding var f: HealthcheckFormState
    @Binding var expanded: Bool
    let editing: Bool
    let detail: HC2CheckDetail?
    let channels: [HC2Channel]
    let channelTypes: [HC2ChannelType]?
    var error: String?

    var body: some View {
        HcCollapsibleSection(
            title: "Notifications & organisation", isExpanded: $expanded,
            hint: "Degraded also notifies on partial failure. Critical ignores quiet hours.",
            error: error
        ) {
            Toggle("Notify when down", isOn: $f.notifyDown)
            Toggle("Notify when back up", isOn: $f.notifyUp)
            Toggle("Notify when degraded", isOn: $f.notifyDegraded)
            Toggle("Critical", isOn: $f.critical)
            HcRepeatPicker(minutes: $f.repeatMinutes, allowsDefault: !(editing && detail?.repeatMinutes != nil))
            HealthcheckChannelPicker(useDefault: $f.useDefaultChannels, selected: $f.channels,
                                     channels: channels, types: channelTypes)
            TextField("Tags, comma-separated", text: $f.tags)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("Group", text: $f.group)
            HcMultilineField(placeholder: "Description", text: $f.description)
            if !editing {
                Toggle("Create paused", isOn: $f.createPaused)
            }
        }
    }
}
