import SwiftUI
import IPv64

/// Header rows (name and value in one row), swipe to delete, masked values unless shown.
struct HeadersEditor: View {
    @Binding var s: ParamsState
    let ini: ParamsState
    let editing: Bool
    @State private var showValues = false

    var body: some View {
        ForEach($s.headers) { $row in
            HStack {
                TextField("Name", text: $row.key).textInputAutocapitalization(.never).autocorrectionDisabled()
                if showValues {
                    TextField("Value", text: $row.value).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                } else {
                    SecureField("Value", text: $row.value).multilineTextAlignment(.trailing)
                }
            }
            .swipeActions {
                Button("Remove header", systemImage: "trash", role: .destructive) {
                    s.headers.removeAll { $0.id == row.id }
                }
                .tint(.red)
                .labelStyle(.iconOnly)
            }
        }
        Button("Add header", systemImage: "plus") { s.headers.append(HeaderRow()) }
        if !s.headers.isEmpty {
            Toggle("Show header values", isOn: $showValues)
        }
        if editing && s.headersNeedReentry(ini) {
            Text("Masked header values can't be sent back; re-enter them when you change headers")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// JSON rules (path, operator, value), swipe to delete.
struct JsonRulesEditor: View {
    @Binding var s: ParamsState

    var body: some View {
        ForEach($s.jsonRules) { $rule in
            VStack(alignment: .leading) {
                TextField("Path", text: $rule.path, prompt: Text(verbatim: "data.items[0].status"))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("Operator", selection: $rule.op) {
                    ForEach(jsonRuleOperators, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
                }
                if rule.op.needsValue {
                    TextField("Value", text: $rule.value).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            }
            .swipeActions {
                Button("Remove rule", systemImage: "trash", role: .destructive) {
                    s.jsonRules.removeAll { $0.id == rule.id }
                }
                .tint(.red)
                .labelStyle(.iconOnly)
            }
        }
        if s.jsonRules.count < 10 {
            Button("Add rule", systemImage: "plus") { s.jsonRules.append(JsonRuleRow()) }
        }
        if s.jsonRules.count > 1 {
            Toggle("Any rule is enough", isOn: $s.jsonAny)
        }
    }
}
