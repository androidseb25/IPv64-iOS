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
                NavigationLink(value: Tabs.account.route) {
                    Text("Account")
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
                Button(action: {}) {
                    Text("YouTube")
                        .foregroundStyle(systemColorScheme == .dark ? Color.white : Color.black)
                }
                
            }
            Button(role: .destructive) {
                
            } label: {
                Text("Logout")
            }
        }
        .showLoading($api.isLoading)
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
            default:
                EmptyView()
            }
        }
    }
}

#Preview {
    SettingsView(popToRootTab: .constant(.settings))
}
