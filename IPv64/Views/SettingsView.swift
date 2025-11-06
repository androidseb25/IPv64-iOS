//
//  SettingsView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct SettingsView: View {
    
    @Environment(\.colorScheme) var systemColorScheme
    
    @Binding var popToRootTab: Tabs
    
    @StateObject private var userStorage = UserStorage.shared
    @StateObject private var api = ApiService()
    
    @State private var alertType: AlertType?
    
    var body: some View {
        NavigationStack {
            if #available(iOS 26.0, *) {
                listView
                    .setColorGradient(.orange)
            } else {
                listView
            }
        }
    }
    
    private var listView: some View {
        List {
            Section("General") {
                if #unavailable(iOS 26.0) {
                    NavigationLink(value: Tabs.account.route) {
                        Text("Account")
                    }
                }
                NavigationLink(value: Tabs.log.route) {
                    Text("Logs")
                }
                NavigationLink(value: Tabs.myip.route) {
                    Text("My IP")
                }
            }
            
            Section("Security") {
                Toggle("Lockscreen \(userStorage.EnableLogscreen ? "enabled" : "disabled")", isOn: $userStorage.EnableLogscreen)
            }
            
            Section("Other") {
                NavigationLink(value: Tabs.about.route) {
                    Text("About")
                }
                #if DEBUG
                NavigationLink(value: Tabs.syslog.route) {
                    Text("System Logs")
                }
                #endif
                Button(action: {
                    if let url = URL(string: "https://www.youtube.com/c/RaspberryPiCloud") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("YouTube")
                        .foregroundStyle(systemColorScheme == .dark ? Color.white : Color.black)
                }
                
            }
            Button(role: .destructive) {
                withAnimation {
                    alertType = .logout
                }
            } label: {
                Text("Logout")
            }
        }
        .navigationTitle(Tabs.settings.labelNew)
        .navigationBarTitleDisplayMode(.inline).navigationDestination(for: String.self) { route in
            switch route {
            case Tabs.account.route:
                Tabs.account.makeContentView(popToRootTab: $popToRootTab)
            case Tabs.log.route:
                Tabs.log.makeContentView(popToRootTab: $popToRootTab)
            case Tabs.myip.route:
                Tabs.myip.makeContentView(popToRootTab: $popToRootTab)
            case Tabs.about.route:
                Tabs.about.makeContentView(popToRootTab: $popToRootTab)
            case Tabs.syslog.route:
                Tabs.syslog.makeContentView(popToRootTab: $popToRootTab)
            default:
                EmptyView()
            }
        }
        .alert(item: $alertType) { type in
            switch type {
            case .logout:
                return Alert(
                    title: Text("Are you sure you want to logout?"),
                    message: Text("You will need to sign in again to access your account."),
                    primaryButton: .destructive(Text("Logout")) {
                        withAnimation {
                            if(performLogout()) {
                                if (!User.empty.list.isEmpty) {
                                    self.alertType = .logoutSuccess
                                }
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .logoutSuccess:
                return Alert(title: Text("Successfully logged out."), message: Text("The app selected the first available user in the list."), dismissButton: .cancel(Text("OK")))
            default:
                return Alert(title: Text(""))
            }
        }
    }
}

#Preview {
    SettingsView(popToRootTab: .constant(.settings))
}
