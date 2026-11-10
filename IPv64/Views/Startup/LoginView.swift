//
//  LoginView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct LoginView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject private var userStorage = UserStorage.shared
    
    @State var isFromAddUser: Bool = false
    
    @State private var showQrSheet = false
    @State private var showSpinner = false
    @State private var showDeniedAlert = false
    @State private var isAuthorized = false
    
    @StateObject private var api = ApiService()
    @State private var loginTask: Task<Void, Never>?
    @State private var apiKey = ""
    
    @State private var user = User.empty
    
    var body: some View {
        VStack {
            if #available(iOS 26.0, *) {
                content
                    .setColorGradient((showQrSheet || isFromAddUser) ? .clear : .orange)
            } else {
                content
            }
        }
        .apiErrors(api)
        .onDisappear { loginTask?.cancel() }
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                if #available(iOS 26.0, *) {
                    scannBtn
                } else {
                    scannBtn
                        .tint(systemColorScheme == .dark ? .white : .black)
                }
            }
        }
        .sheet(isPresented: $showQrSheet.animation()) {
            QRScannerView() { key in
                
                apiKey = key
                loginTask?.cancel()
                loginTask = Task { await login(key) }
            }.onDisappear {
                withAnimation {
                    showQrSheet = false
                    showSpinner = false
                }
            }
        }
        .task {
            await permissisenCheck()
        }
        .alert("No Camera Permission", isPresented: $showDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow camera access in Settings to use this feature.")
        }
        .overlay(alignment: .bottom) {
            VStack {
                if #available(iOS 26.0, *) {
                    letsgoBtn
                        .glassEffect(.regular.tint(.orange).interactive(true))
                } else {
                    letsgoBtn
                        .background(RoundedRectangle(cornerRadius: 24).fill(.orange))
                }
            }
            .padding()
        }
    }
    
    private var content: some View {
        return List {
            Text("How do you log in to IPv64.net?")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            
            VStack(spacing: 5) {
                Text("**1.** Go to ipv64.net and log in to your account.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("**2.** Select the **Account** button at the top.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("**3.** A drop-down menu will open. Select **API**.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("**4.** You will now see a list of API keys (if you have already created more than one). Select the one you want to use by tapping the QR code button.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("**5.** Open the QR code scanner in this app and scan the QR code.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("**6.** Done! You are now logged in.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.footnote)
            .listRowBackground(Color.clear)
            
            Section {
                TextField("API Key", text: $apiKey)
                    .multilineTextAlignment(.leading)
                    .keyboardType(.default)
                    .lineLimit(3)
                    .tint(.orange)
            }
        }
    }
    
    private var letsgoBtn: some View {
        return Button (action: {
            loginTask?.cancel()
            loginTask = Task { await login(apiKey) }
        }) {
            Text("Login")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(16)
        }
        .disabled(api.isLoading || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .overlay { if api.isLoading { ProgressView() } }
    }

    private func login(_ rawKey: String) async {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !api.isLoading else { return }
        guard let account = await api.GetAccountStatus(token: key), !Task.isCancelled else { return }
        guard APITransport.isSuccessStatus(account.status), account.account_status == 1 else {
            api.errorMessage = "This API key does not belong to an active account."
            return
        }
        if !user.list.contains(where: { $0.ApiKey == key }) {
            user = User(Username: account.email, ApiKey: key, Information: "")
            user.save()
            guard user.list.contains(where: { $0.ApiKey == key }) else { return }
        }
        userStorage.ApiKey = key
        guard userStorage.ApiKey == key else { return }
        if userStorage.ApiKeyWidget.isEmpty { userStorage.ApiKeyWidget = key }
        if isFromAddUser { presentationMode.wrappedValue.dismiss() }
        else { userStorage.ShowLoginView = false }
    }
    
    private var scannBtn: some View {
        return Button (action: {
            if (!isAuthorized) {
                Task {
                    await permissisenCheck(true)
                }
            } else {
                withAnimation {
                    showQrSheet = true
                    showSpinner = true
                }
            }
        }) {
            if (showSpinner) {
                Spinner(isAnimating: true, style: .medium, color: .white)
            } else {
                Label("Show QR Scanner", systemImage: "qrcode")
            }
        }
    }
    
    private func permissisenCheck(_ isFromButton: Bool = false) async {
        switch CameraPermission.status() {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            let newStatus = await CameraPermission.request()
            isAuthorized = (newStatus == .authorized)
            showDeniedAlert = (newStatus != .authorized)
            if (isFromButton && isAuthorized) {
                withAnimation {
                    showQrSheet = true
                    showSpinner = true
                }
            }
        case .denied, .restricted:
            showDeniedAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
        
    }
}
