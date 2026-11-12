import SwiftUI
import IPv64

/// Text input kinds of the check forms.
enum HcFieldKind { case text, url, number, decimal, secure }

/// Digits only (decimal: "," becomes ".", one dot).
nonisolated func hcFilterNumber(_ text: String, decimal: Bool) -> String {
    var seenDot = false
    var out = ""
    for ch in text.replacingOccurrences(of: ",", with: decimal ? "." : "") {
        if ch.isASCII && ch.isNumber { out.append(ch) } else if decimal && ch == "." && !seenDot { seenDot = true; out.append(ch) }
    }
    return out
}

/// Label with the value right-aligned (like Settings); numbers get an optional unit suffix.
struct HcFieldRow: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var kind: HcFieldKind = .text
    var prompt = ""
    var unit: LocalizedStringKey?

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                input.multilineTextAlignment(.trailing)
                if let unit { Text(unit).foregroundStyle(.secondary) }
            }
        }
        .onChange(of: text) {
            guard kind == .number || kind == .decimal else { return }
            let filtered = hcFilterNumber(text, decimal: kind == .decimal)
            if filtered != text { text = filtered }
        }
    }

    @ViewBuilder private var input: some View {
        switch kind {
        case .secure: SecureField(prompt, text: $text)
        case .number: TextField(prompt, text: $text).keyboardType(.numberPad)
        case .decimal: TextField(prompt, text: $text).keyboardType(.decimalPad)
        case .url: TextField(prompt, text: $text).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
        case .text: TextField(prompt, text: $text).textInputAutocapitalization(.never).autocorrectionDisabled()
        }
    }
}

/// Multi-line text with the label as placeholder.
struct HcMultilineField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical).lineLimit(2...8)
    }
}

/// Optional whole number as a stepper; stepping below the minimum clears it (server default).
struct HcStepperRow: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let range: ClosedRange<Int>

    private var current: Int? { Int(text.trimmingCharacters(in: .whitespaces)) }

    var body: some View {
        Stepper {
            LabeledContent(label) { Text(verbatim: current.map(String.init) ?? String(localized: "Default")) }
        } onIncrement: {
            text = String(min((current ?? range.lowerBound - 1) + 1, range.upperBound))
        } onDecrement: {
            guard let current else { return }
            text = current <= range.lowerBound ? "" : String(current - 1)
        }
    }
}

/// Duration as presets (the loaded value is added when it is not a preset).
struct HcDurationPicker: View {
    let label: LocalizedStringKey
    @Binding var value: String
    @Binding var unit: Int
    let presets: [Int]
    var allowsDefault = true

    private var seconds: Int? {
        durationToSeconds(value, unitIdx: unit).flatMap { $0 > 0 ? $0 : nil }
    }

    private var options: [Int?] {
        var list: [Int?] = presets.map { Optional($0) }
        if let seconds, !presets.contains(seconds) { list.append(seconds); list.sort { ($0 ?? 0) < ($1 ?? 0) } }
        return allowsDefault || seconds == nil ? [nil] + list : list
    }

    var body: some View {
        Picker(label, selection: Binding(get: { seconds }, set: { new in
            (value, unit) = secondsToDuration(new)
        })) {
            ForEach(options, id: \.self) { option in
                Text(verbatim: option.map { HcFormat.duration(seconds: $0) } ?? String(localized: "Default")).tag(option)
            }
        }
    }
}

/// Repeat reminder picker.
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
                Text(verbatim: option.map(HcFormat.repeatMinutes) ?? String(localized: "Default")).tag(option)
            }
        }
    }
}

/// Section footer: explanation in secondary, validation message in red.
struct HcFooter: View {
    var hint: LocalizedStringKey?
    var error: String?

    var body: some View {
        if hint != nil || error != nil {
            VStack(alignment: .leading, spacing: 4) {
                if let hint { Text(hint) }
                if let error { Text(verbatim: error).foregroundStyle(.red) }
            }
        }
    }
}

/// Section whose header toggles it (header button with a rotating chevron, like Events in the detail).
struct HcCollapsibleSection<Content: View>: View {
    let title: LocalizedStringKey
    @Binding var isExpanded: Bool
    var hint: LocalizedStringKey?
    var error: String?
    @ViewBuilder var content: Content

    var body: some View {
        Section {
            if isExpanded { content }
        } header: {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: "chevron.right").rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        } footer: {
            HcFooter(hint: isExpanded ? hint : nil, error: error)
        }
    }
}
