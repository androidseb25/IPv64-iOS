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
    @State private var showWhatsNew = false
    @State private var activeSheet: ActiveSheet? = nil
    
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
        .onAppear {
            let bnd = Int(userStorage.LAST_BUILD_NUMBER) ?? 0
            
            if bnd != Int(Bundle.main.buildNumber) && !userStorage.ShowWelcomeView {
                withAnimation {
                    showWhatsNew = true
                    activeSheet = .whatsnew
                }
            }
        }
        .sheet(item: $activeSheet) { item in
            showActiveSheet(item: item)
        }
    }
    
    @ViewBuilder
    private func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .whatsnew:
            if #available(iOS 26.0, *) {
                WhatsNewView26(activeSheet: $activeSheet, isPresented: $showWhatsNew, isFromSetting: true)
                    .interactiveDismissDisabled(true)
            } else {
                WhatsNewView(activeSheet: $activeSheet, isPresented: $showWhatsNew, isFromSetting: true)
                    .interactiveDismissDisabled(true)
            }
        default:
            EmptyView()
        }
    }
}

#Preview {
    ContentView()
}
