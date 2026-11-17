import SwiftUI
import IPv64

/// "General" section of the channel form.
struct ChannelGeneralSection: View {
    @Binding var name: String
    @Binding var enabled: Bool
    @Binding var isDefault: Bool
    @Binding var notifyDown: Bool
    @Binding var notifyUp: Bool
    @Binding var lang: HC2ChannelLanguage
    let showValidation: Bool

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Name", text: $name)
                if showValidation && name.nonBlank == nil {
                    Text("Required").font(.caption).foregroundStyle(.red)
                }
            }
            Toggle("Enabled", isOn: $enabled)
            Toggle(isOn: $isDefault) {
                Text("Default channel")
                Text("Checks without explicit channels notify default channels.")
            }
            Toggle("Notify when a check goes down", isOn: $notifyDown)
            Toggle("Notify when a check recovers", isOn: $notifyUp)
            Picker("Language", selection: $lang) {
                Text(verbatim: "English").tag(HC2ChannelLanguage.en)
                Text(verbatim: "Deutsch").tag(HC2ChannelLanguage.de)
            }
        } header: {
            Text("General")
        }
    }
}

/// One dynamic config field of the channel type.
struct ChannelFieldRow: View {
    let field: HC2ChannelType.Field
    @Binding var value: String
    let required: Bool
    let error: String?
    let secretIsSet: Bool

    @State private var revealed = false

    private var kind: String { ChannelLogic.kindKey(field) }
    private var label: String { (field.label?.nonBlank ?? field.key ?? "") + (required ? " *" : "") }

    var body: some View {
        switch kind {
        case "bool":
            Toggle(isOn: Binding(get: { ChannelLogic.parseBool(value) }, set: { value = String($0) })) {
                Text(verbatim: label)
            }
        case "select":
            Picker(selection: $value) {
                if !required { Text(verbatim: "–").tag("") }
                ForEach((field.options ?? []).filter { !$0.isEmpty }, id: \.self) { Text(verbatim: $0).tag($0) }
            } label: {
                Text(verbatim: label)
            }
            .foregroundStyle(error == nil ? Color.primary : Color.red)
        default:
            VStack(alignment: .leading, spacing: 4) {
                input
                if let error { Text(verbatim: error).font(.caption).foregroundStyle(.red) }
            }
        }
    }

    @ViewBuilder
    private var input: some View {
        if ChannelLogic.isSecret(field) {
            HStack {
                Group {
                    if revealed {
                        TextField(label, text: $value, prompt: prompt)
                    } else {
                        SecureField(label, text: $value, prompt: prompt)
                    }
                }
                .textContentType(.password)
                Button(revealed ? "Hide" : "Show", systemImage: revealed ? "eye.slash" : "eye") { revealed.toggle() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        } else if kind == "textarea" {
            TextField(label, text: $value, axis: .vertical).lineLimit(3...)
        } else {
            TextField(label, text: $value)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    private var prompt: Text? { secretIsSet ? Text("Set – leave empty to keep") : Text(verbatim: label) }

    private var keyboard: UIKeyboardType {
        switch kind {
        case "url": .URL
        case "email": .emailAddress
        case "number": .decimalPad
        default: .default
        }
    }
}
