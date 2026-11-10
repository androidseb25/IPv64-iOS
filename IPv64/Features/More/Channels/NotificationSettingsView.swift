import SwiftUI
import IPv64

/// Notification settings (spec 04 §7b): quiet hours, rate limit and batching. PATCH sends changes only.
struct NotificationSettingsView: View {
    @Environment(Session.self) private var session

    @State private var baseline: NotificationSettingsForm?
    @State private var present: Set<String> = []
    @State private var form = NotificationSettingsForm()
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: ErrorText?
    @State private var message: ErrorText?

    private var changed: Bool { baseline != nil && form != baseline }
    private var valid: Bool { baseline.map { NotificationSettingsLogic.isValid(form, base: $0) } ?? false }

    var body: some View {
        Form {
            if let baseline {
                QuietHoursSection(form: $form)
                Section("Rate limit and batching") {
                    NumberSettingRow(label: "Notifications per hour", text: $form.rate,
                                     supporting: NotificationSettingsLogic.rateOK(form) ? "0 = unlimited" : "Enter a whole number.",
                                     isError: !NotificationSettingsLogic.rateOK(form))
                    numberRow("Batch threshold", text: $form.threshold, baseline: baseline.threshold,
                              supporting: "From this many notifications they are combined into one.")
                    numberRow("Batch window (seconds)", text: $form.window, baseline: baseline.window,
                              supporting: "Time span in which notifications are counted.")
                }
            }
        }
        .navigationTitle("Notification settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save", systemImage: "checkmark", action: save)
                    .disabled(!changed || !valid || isSaving)
            }
        }
        .loadingOverlay((isLoading && baseline == nil) || isSaving, text: isSaving ? "Saving..." : "Loading...")
        .refreshable { await load(pull: true) }
        .task(id: session.accountRevision) { await load(pull: false) }
        .errorAlert($error) { Task { await load(pull: false) } }
        .errorAlert($message)
    }

    private func numberRow(_ label: LocalizedStringKey, text: Binding<String>, baseline: String,
                           supporting: LocalizedStringKey) -> NumberSettingRow {
        let ok = NotificationSettingsLogic.requiredNumberOK(text.wrappedValue, baseline: baseline)
        return NumberSettingRow(label: label, text: text, supporting: ok ? supporting : "Enter a whole number (cannot be empty).",
                                isError: !ok)
    }

    /// Pull-to-refresh discards edits; the first load fills the form.
    private func load(pull: Bool) async {
        isLoading = true
        defer { isLoading = false }
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
            baseline = f   // nothing to send (e.g. only an empty field without server value)
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
                message = ErrorText(title: String(localized: "Saved"), message: String(localized: "Notification settings were updated."))
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
                    Text("Select at least one day.").foregroundStyle(Color.ipv64Red)
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
        LabeledContent(label) {
            DatePicker(selection: date, displayedComponents: .hourAndMinute) { Text(label) }
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "de_DE"))   // 24 h like Android's picker
        }
    }
}

/// Mon…Sun toggles (several days at once, so chips instead of a segmented picker).
private struct DayChips: View {
    @Binding var days: Set<Int>

    private static let labels: [LocalizedStringKey] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        // Scrolls only when the seven chips don't fit (narrow width, large Dynamic Type).
        ViewThatFits(in: .horizontal) {
            chips
            ScrollView(.horizontal, showsIndicators: false) { chips }
        }
    }

    private var chips: some View {
        AppGlassGroup {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    let day = index + 1
                    let selected = days.contains(day)
                    Button {
                        if selected { days.remove(day) } else { days.insert(day) }
                    } label: {
                        Text(Self.labels[index]).font(.subheadline)
                    }
                    .appChipButtonStyle(selected: selected)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct NumberSettingRow: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let supporting: LocalizedStringKey
    let isError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(isError ? Color.ipv64Red : Color.secondary)
            TextField(label, text: $text)
                .keyboardType(.numberPad)
                .onChange(of: text) { _, new in
                    let digits = new.filter(\.isNumber)
                    if digits != new { text = digits }
                }
            Text(supporting).font(.caption).foregroundStyle(isError ? Color.ipv64Red : Color.secondary)
        }
    }
}
