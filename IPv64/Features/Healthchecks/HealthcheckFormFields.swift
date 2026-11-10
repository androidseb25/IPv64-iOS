import SwiftUI

/// Text input kinds of the check forms.
enum HcFieldKind { case text, url, number, decimal, secure }

/// Digits only (decimal: "," → ".", one dot).
nonisolated func hcFilterNumber(_ text: String, decimal: Bool) -> String {
    var seenDot = false
    var out = ""
    for ch in text.replacingOccurrences(of: ",", with: decimal ? "." : "") {
        if ch.isASCII && ch.isNumber { out.append(ch) } else if decimal && ch == "." && !seenDot { seenDot = true; out.append(ch) }
    }
    return out
}

/// Label + trailing text field (or a multi-line field) with an optional supporting text.
struct HcField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var kind: HcFieldKind = .text
    var prompt = ""
    var footer: LocalizedStringKey?
    var multiline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if multiline {
                Text(label).font(.subheadline).foregroundStyle(.secondary)
                TextField("", text: $text, prompt: Text(verbatim: prompt), axis: .vertical).lineLimit(2...8)
            } else {
                LabeledContent(label) { input.multilineTextAlignment(.trailing) }
            }
            if let footer { Text(footer).font(.caption).foregroundStyle(.secondary) }
        }
        .onChange(of: text) {
            guard kind == .number || kind == .decimal else { return }
            let filtered = hcFilterNumber(text, decimal: kind == .decimal)
            if filtered != text { text = filtered }
        }
    }

    @ViewBuilder
    private var input: some View {
        switch kind {
        case .secure:
            SecureField("", text: $text, prompt: Text(verbatim: prompt))
        case .number:
            TextField("", text: $text, prompt: Text(verbatim: prompt)).keyboardType(.numberPad)
        case .decimal:
            TextField("", text: $text, prompt: Text(verbatim: prompt)).keyboardType(.decimalPad)
        case .url:
            TextField("", text: $text, prompt: Text(verbatim: prompt))
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
        case .text:
            TextField("", text: $text, prompt: Text(verbatim: prompt))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        }
    }
}

/// Switch with an optional supporting text.
struct HcToggle: View {
    let label: LocalizedStringKey
    @Binding var isOn: Bool
    var footer: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(label, isOn: $isOn)
            if let footer { Text(footer).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

/// Number + unit (seconds … days) (Android `DurationField`).
struct HcDurationField: View {
    let label: LocalizedStringKey
    @Binding var value: String
    @Binding var unit: Int
    var footer: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(label) {
                HStack {
                    TextField("", text: $value).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    Picker("Unit", selection: $unit) {
                        Text("seconds").tag(0)
                        Text("minutes").tag(1)
                        Text("hours").tag(2)
                        Text("days").tag(3)
                    }
                    .labelsHidden()
                }
            }
            if let footer { Text(footer).font(.caption).foregroundStyle(.secondary) }
        }
        .onChange(of: value) {
            let filtered = hcFilterNumber(value, decimal: false)
            if filtered != value { value = filtered }
        }
    }
}

/// Repeat reminder picker (shared by account and node forms).
struct HcRepeatPicker: View {
    @Binding var minutes: Int?
    /// Edit: "Default" is removed when the loaded check has a value.
    var allowsDefault = true

    private var options: [Int?] {
        var list = healthcheckRepeatOptions.filter { allowsDefault || $0 != nil }
        if let minutes, !list.contains(minutes) { list.append(minutes) }
        return list
    }

    var body: some View {
        Picker("Repeat reminder", selection: $minutes) {
            ForEach(options, id: \.self) { option in
                Text(verbatim: option.map(Formatters.repeatMinutes) ?? String(localized: "Default")).tag(option)
            }
        }
    }
}
