import SwiftUI
import IPv64

/// "Password check" (spec 04 §12): SHA-1 on device, only the 5-char prefix is sent.
struct PasswordCheckView: View {
    @Environment(Session.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    @State private var password = ""
    @State private var revealed = false
    @State private var result: Int?
    @State private var isBusy = false
    @State private var generation = 0
    @State private var error: ErrorText?

    var body: some View {
        Form {
            Section {
                Text("Find out whether a password was tried by attackers at Honeypot64 sensors. The password is hashed on your device (SHA-1) and only the first 5 characters of the hash are sent. The password itself never leaves your device.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Group {
                        if revealed { TextField("Password", text: $password) } else { SecureField("Password", text: $password) }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit(check)
                    Button(revealed ? "Hide password" : "Show password", systemImage: revealed ? "eye.slash" : "eye") {
                        revealed.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
                Button("Check password", action: check).disabled(password.isEmpty || isBusy)
                if !password.isEmpty {
                    Button("Clear", role: .cancel, action: clear)
                }
            }
            if let result {
                Section("Result") {
                    HStack {
                        StatusChip(result > 0 ? "Found in attacks" : "Not found", color: result > 0 ? .ipv64Red : .ipv64Green)
                    }
                    Text(result > 0
                         ? "This password was used \(Formatters.count(result)) times in attacks. Do not use it and change it everywhere you use it."
                         : "This password was not seen in the Honeypot64 data. That does not mean it is safe: use long, unique passwords and a password manager.")
                }
            }
        }
        .navigationTitle("Password check")
        .navigationBarTitleDisplayMode(.inline)
        .privacyProtected()
        .overlay { if isBusy { LoadingView("Checking...") } }
        .onChange(of: password) { result = nil }
        .onChange(of: scenePhase) { if scenePhase != .active { clear() } }
        .onDisappear(perform: clear)
        .errorAlert($error)
    }

    private func clear() {
        generation += 1
        password = ""
        revealed = false
        result = nil
        isBusy = false
    }

    private func check() {
        guard !password.isEmpty, !isBusy else { return }
        generation += 1
        let mine = generation
        let (prefix, suffix) = SecurityLogic.prefixAndSuffix(password)
        isBusy = true
        Task {
            defer { if mine == generation { isBusy = false } }
            do {
                let entries = try await ipv64Retrying { try await session.api.threat.passwordRangeEntries(prefix: prefix) }
                guard mine == generation else { return }
                result = SecurityLogic.count(forSuffix: suffix, in: entries.map { ($0.suffix, $0.count) })
            } catch is CancellationError {
            } catch {
                if mine == generation { self.error = ErrorText(error) }
            }
        }
    }
}
