import SwiftUI
import IPv64

/// "Verify channel": send a 6-digit code, enter it. Never swipe-dismissible; closes via "Later" or a successful verification.
struct ChannelVerifySheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    let channelId: Int
    let name: String
    let onVerified: () -> Void
    /// "Later" (e.g. closes the setup sheet after a create).
    var onLater: () -> Void = {}

    @State private var codeSent = false
    @State private var code = ""
    @State private var isBusy = false
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var countdown = 0
    @State private var sendCount = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    content
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let infoText { Text(verbatim: infoText) }
                        if let errorText { Text(verbatim: errorText).foregroundStyle(.red) }
                    }
                }
            }
            .navigationTitle("Verify channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later", systemImage: "clock") {
                        dismiss()
                        onLater()
                    }
                    .disabled(isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isBusy {
                        ProgressView()
                    } else if !codeSent {
                        Button("Send code", systemImage: "paperplane", action: sendCode)
                    } else {
                        Button("Verify", systemImage: "checkmark", action: verify).disabled(code.count != 6)
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .appReadableWidth()
        .presentationDetents([.medium, .large])
        .task(id: sendCount) { await runCountdown() }
    }

    @ViewBuilder
    private var content: some View {
        if !codeSent {
            Text("A 6-digit code will be sent to “\(name)”.")
            Text("You can request up to 5 codes per hour. Each code is valid for 15 minutes.")
                .font(.footnote).foregroundStyle(.secondary)
        } else {
            Text("Enter the 6-digit code sent to “\(name)”.")
            TextField("Code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.title3.monospacedDigit())
                .foregroundStyle(errorText == nil ? Color.primary : Color.red)
                .onChange(of: code) { _, new in
                    let digits = String(new.filter(\.isNumber).prefix(6))
                    if digits != new { code = digits }
                    errorText = nil
                }
            Button(action: sendCode) {
                countdown > 0 ? Text("Resend code (\(countdown) s)") : Text("Resend code")
            }
            .disabled(isBusy || countdown > 0)
            Text("Up to 5 codes per hour, valid for 15 minutes.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func runCountdown() async {
        guard sendCount > 0 else { return }
        countdown = 60
        while countdown > 0 {
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            countdown -= 1
        }
    }

    /// Without auto-retry: a 429 has a meaning here.
    private func sendCode() {
        guard !isBusy else { return }
        let client = session.api
        let wasSent = codeSent
        Task {
            isBusy = true
            errorText = nil
            infoText = nil
            defer { isBusy = false }
            do {
                _ = try await client.hc2.channels.sendVerificationCode(channelId)
                if wasSent { infoText = String(localized: "A new code has been sent.") }
                codeSent = true
                sendCount += 1
            } catch let error as IPv64Error where error.statusCode == 429 {
                errorText = String(localized: "Too many codes requested, try again later.")
            } catch {
                errorText = ErrorText(error).message
            }
        }
    }

    private func verify() {
        guard !isBusy, code.count == 6 else { return }
        let client = session.api
        let code = code
        Task {
            isBusy = true
            errorText = nil
            defer { isBusy = false }
            do {
                _ = try await client.hc2.channels.verify(channelId, code: code)
                dismiss()
                onVerified()
            } catch let error as IPv64Error where error.statusCode == 429 {
                errorText = String(localized: "Too many attempts, try again later.")
            } catch let error as IPv64Error where error.statusCode == 422 || error.code == "invalid_code" {
                errorText = String(localized: "Invalid or expired code.")
            } catch {
                errorText = ErrorText(error).message
            }
        }
    }
}
