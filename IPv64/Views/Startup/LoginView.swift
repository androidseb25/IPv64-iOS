//
//  LoginView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

import SwiftUI

struct LoginView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject private var userStorage = UserStorage.shared
    
    @State var isFromAddUser: Bool = false
    
    @State private var showQrSheet = false
    @State private var showSpinner = false
    @State private var showDeniedAlert = false
    @State private var isAuthorized = false
    
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
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                if #available(iOS 26.0, *) {
                    scannBtn
                } else {
                    scannBtn
                        .tint(.orange)
                }
            }
        }
        .sheet(isPresented: $showQrSheet.animation()) {
            QRScannerView() { key in
                
                let isContains = user.list.contains(where: { $0.ApiKey == key })
                
                if (isContains) {
                    return
                }
                
                user.ApiKey = key
                user.Username = user.list.count > 0 ? "Default User \(user.list.count)" : "Default User"
                user.Information = ""
                user.save()
                
                apiKey = key
                userStorage.ApiKey = key
                
                if (isFromAddUser) {
                    presentationMode.wrappedValue.dismiss()
                } else {
                    userStorage.ShowLoginView = false
                }
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
            withAnimation {
                
                let isContains = user.list.contains(where: { $0.ApiKey == apiKey })
                
                if (isContains) {
                    return
                }
                
                user.ApiKey = apiKey
                user.Username = user.list.count > 0 ? "Default User \(user.list.count)" : "Default User"
                user.Information = ""
                user.save()
                
                userStorage.ApiKey = apiKey
                
                if (isFromAddUser) {
                    presentationMode.wrappedValue.dismiss()
                } else {
                    userStorage.ShowLoginView = false
                }
            }
        }) {
            Text("Login")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(16)
        }
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
