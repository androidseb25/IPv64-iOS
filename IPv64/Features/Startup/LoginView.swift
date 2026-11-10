import SwiftUI
import AVFoundation

/// Login with an API key (spec 01 §3.2). `isFromUser == true`: added from the Users list
/// (back button, does not switch the active account).
struct LoginView: View {
    let isFromUser: Bool

    @Environment(Session.self) private var session
    @Environment(Router.self) private var router: Router?
    @Environment(\.openURL) private var openURL

    @State private var apiKey = ""
    @State private var showScanner = false
    @State private var alert: LoginAlert?

    var body: some View {
        Form {
            Section {
                Text("**1.** Go to ipv64.net and log in to your account.")
                Text("**2.** Select the **Account** button at the top.")
                Text("**3.** A drop-down menu will open. Select **API**.")
                Text("**4.** You will now see a list of API keys (if you have already created more than one). Select the one you want to use by tapping the QR code button.")
                Text("**5.** Open the QR code scanner in this app and scan the QR code.")
                Text("**6.** Done! You are now logged in.")
            }
            Section {
                TextField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.callout)
                    .submitLabel(.go)
                    .onSubmit(login)
            }
            Section {
                Button("Login", action: login)
                    .frame(maxWidth: .infinity)
                    .disabled(apiKey.isEmpty)
            }
        }
        .navigationTitle("Login")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Scannen", systemImage: "qrcode.viewfinder") { Task { await openCamera() } }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerView { apiKey = $0 }
        }
        .alert(item: $alert) { alert in
            switch alert {
            case .alreadyAdded:
                Alert(title: Text("This account has already been added."))
            case .cameraDenied:
                Alert(title: Text("Camera permission is denied. Enable it in the app settings."),
                      dismissButton: .default(Text("OK")) {
                          if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                      })
            }
        }
    }

    private func login() {
        // iOS: pasted keys often carry a trailing newline (Android passes the raw value).
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        switch session.login(apiKey: key, isFromUser: isFromUser) {
        case .alreadyAdded: alert = .alreadyAdded
        case .added: router?.pop()
        case .activated: break   // RootView switches to the tab shell
        }
    }

    /// Android camera permission flow; iOS can ask only once, afterwards the Settings app is the way.
    private func openCamera() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showScanner = true
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) { showScanner = true } else { alert = .cameraDenied }
        default:
            alert = .cameraDenied
        }
    }
}

private enum LoginAlert: Identifiable {
    case alreadyAdded, cameraDenied
    var id: Self { self }
}

#Preview {
    NavigationStack { LoginView(isFromUser: false) }
        .environment(Session())
}
