import SwiftUI
import IPv64

/// Notification settings (pushed from More): quiet hours, rate limit and batching. PATCH sends changes only.
struct NotificationSettingsView: View {
    @Environment(Session.self) private var session

    @State private var baseline: NotificationSettingsForm?
    @State private var present: Set<String> = []
    @State private var form = NotificationSettingsForm()
    @State private var isSaving = false
    @State private var error: ErrorText?

    private var changed: Bool { baseline != nil && form != baseline }
    private var valid: Bool { baseline.map { NotificationSettingsLogic.isValid(form, base: $0) } ?? false }

    var body: some View {
        if #available(iOS 26.0, *) {
            formView.setColorGradient(.orange)
        } else {
            formView
        }
    }

    private var formView: some View {
        Form {
            if let baseline {
                QuietHoursSection(form: $form)
                Section {
                    NumberSettingRow(label: "Notifications per hour", text: $form.rate,
                                     supporting: "0 = unlimited", isError: !NotificationSettingsLogic.rateOK(form))
                    requiredRow("Batch threshold", text: $form.threshold, baseline: baseline.threshold,
                                supporting: "From this many notifications they are combined into one.")
                    requiredRow("Batch window (seconds)", text: $form.window, baseline: baseline.window,
                                supporting: "Time span in which notifications are counted.")
                } header: {
                    Text("Rate limit and batching")
                }
            }
        }
        .overlay {
            if baseline == nil && error == nil { ProgressView() }
        }
        .navigationTitle("Notification settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if changed {
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save", systemImage: "checkmark", action: save).disabled(!valid)
                    }
                }.appVerticalPreferred()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(isSaving)
        .refreshable { await load(pull: true) }
        .task { await load(pull: false) }
        .errorAlert($error)
    }

    private func requiredRow(_ label: LocalizedStringKey, text: Binding<String>, baseline: String,
                             supporting: LocalizedStringKey) -> some View {
        let ok = NotificationSettingsLogic.requiredNumberOK(text.wrappedValue, baseline: baseline)
        return NumberSettingRow(label: label, text: text,
                                supporting: ok ? supporting : "Enter a whole number (cannot be empty).", isError: !ok)
    }

    /// Pull-to-refresh discards edits; the first load fills the form.
    private func load(pull: Bool) async {
        let client = session.api
        do {
            let parsed = NotificationSettingsLogic.parse(try await ipv64Retrying { try await client.hc2.settings() })
            if pull || baseline == nil { form = parsed.form }
            baseline = parsed.form
            present = parsed.present
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func save() {
        guard let base = baseline, valid else { return }
        let f = form
        let update = NotificationSettingsLogic.update(f, base: base, present: present)
        guard update != HC2SettingsInput() else {
            baseline = f   // nothing to send (e.g. only an empty field without a server value)
            return
        }
        let client = session.api
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                let result = NotificationSettingsLogic.parse(try await ipv64Retrying { try await client.hc2.updateSettings(update) })
                if result.present.isEmpty {
                    baseline = f
                    present.formUnion(NotificationSettingsLogic.quietKeys)
                } else {
                    baseline = result.form
                    present.formUnion(result.present)
                    form = result.form
                }
            } catch {
                self.error = ErrorText(error)
            }
        }
    }
}

private struct QuietHoursSection: View {
    @Binding var form: NotificationSettingsForm

    var body: some View {
        Section {
            Toggle(isOn: $form.quietEnabled) {
                Text("Enable quiet hours")
                Text("Notifications are held back during these hours.")
            }
            if form.quietEnabled {
                TimeOfDayRow(label: "From", value: $form.from)
                TimeOfDayRow(label: "To", value: $form.to)
                DayChips(days: $form.days)
            }
        } header: {
            Text("Quiet hours")
        } footer: {
            if form.quietEnabled {
                if form.days.isEmpty {
                    Text("Select at least one day.").foregroundStyle(.red)
                } else {
                    Text("Times use the server's time zone.")
                }
            }
        }
    }
}

/// "HH:mm" (24 h) via the system time picker.
private struct TimeOfDayRow: View {
    let label: LocalizedStringKey
    @Binding var value: String

    private var date: Binding<Date> {
        Binding {
            let parts = value.split(separator: ":").compactMap { Int($0) }
            return Calendar.current.date(bySettingHour: parts.first ?? 0, minute: parts.count > 1 ? parts[1] : 0,
                                         second: 0, of: .now) ?? .now
        } set: { new in
            let c = Calendar.current.dateComponents([.hour, .minute], from: new)
            value = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        }
    }

    var body: some View {
        DatePicker(label, selection: date, displayedComponents: .hourAndMinute)
            .environment(\.locale, Locale(identifier: "de_DE"))   // 24 h like Android's picker
    }
}

/// Mon…Sun toggles (several days at once, so buttons instead of a segmented picker).
private struct DayChips: View {
    @Binding var days: Set<Int>

    private static let labels: [LocalizedStringKey] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        // Scrolls only when the seven buttons don't fit (narrow width, large Dynamic Type).
        ViewThatFits(in: .horizontal) {
            chips
            ScrollView(.horizontal, showsIndicators: false) { chips }
        }
    }

    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let day = index + 1
                let selected = days.contains(day)
                Button {
                    if selected { days.remove(day) } else { days.insert(day) }
                } label: {
                    Text(Self.labels[index]).font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(selected ? .orange : .gray)
                .controlSize(.small)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 2)
    }
}

private struct NumberSettingRow: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let supporting: LocalizedStringKey
    let isError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(label) {
                TextField(label, text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: text) { _, new in
                        let digits = new.filter(\.isNumber)
                        if digits != new { text = digits }
                    }
            }
            Text(supporting).font(.caption).foregroundStyle(isError ? Color.red : Color.secondary)
        }
    }
}
