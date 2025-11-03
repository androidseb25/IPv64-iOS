//
//  ContentView.swift
//  IPv64
//
//  Created by Sebastian Rank on 18.10.25.
//

import SwiftUI

struct ContentView: View {
    
    @Environment(\.scenePhase) var scenePhase
    
    @StateObject var networkMonitor = NetworkMonitor()
    @StateObject private var biometrics = Biometrics()
    @StateObject private var userStorage = UserStorage.shared
    
    var body: some View {
        ZStack {
            if (userStorage.ShowWelcomeView) {
                WelcomeView()
            } else if !biometrics.isAuthenticated && userStorage.EnableLogscreen {
                BiometricsLockView()
                    .environmentObject(biometrics)
            } else if !networkMonitor.isConnected {
                NoConnectionView()
            } else if userStorage.ShowLoginView || userStorage.ApiKey.isEmpty {
                NavigationStack {
                    LoginView()
                }
            } else {
                if #available(iOS 26.0, *) {
                    TabbarView()
                        .tint(.orange)
                } else {
                    TabbarView18()
                        .tint(.orange)
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            print(newPhase)
            if newPhase == .active {
                userStorage.InAppSwitcher = false
            } else if newPhase == .inactive {
                biometrics.isAuthenticated = false
                userStorage.InAppSwitcher = true
            } else if newPhase == .background {
                biometrics.disableFields = false
                biometrics.isAuthenticated = false
                userStorage.InAppSwitcher = false
            }
        }
    }
}

#Preview {
    ContentView()
}
