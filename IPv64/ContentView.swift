//
//  ContentView.swift
//  IPv64
//
//  Created by Sebastian Rank on 18.10.25.
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    
    @Environment(\.scenePhase) var scenePhase
    
    @StateObject var networkMonitor = NetworkMonitor()
    @EnvironmentObject private var biometrics: Biometrics
    @StateObject private var userStorage = UserStorage.shared
    @State private var showWhatsNew = false
    @State private var activeSheet: ActiveSheet? = nil
    @Environment(Session.self) private var session
    @Environment(PushRegistrar.self) private var registrar
    @Environment(ConnectedNodes.self) private var nodes
    @State private var showPushSetup = false
    
    /// After login: sync a changed device token, then open "Push notifications" once per account unless it is
    /// done or this device already has a channel (Android `MainActivity` + `PushSetupStore.shouldShow`).
    private func runPushLogic() async {
        let apiKey = session.apiKey
        await registrar.ensureAccountId()
        nodes.syncWithCloud(force: true)
        _ = try? await registrar.syncTokenIfChanged(channels: nil)
        guard !Task.isCancelled, PushSetupStore.shouldShow(apiKey: apiKey),
              let account = PushSetupStore.scope(apiKey: apiKey), registrar.setupTriggeredFor != account else { return }
        registrar.setupTriggeredFor = account
        showPushSetup = true
    }

    var body: some View {
        ZStack {
            if (userStorage.ShowWelcomeView) {
                WelcomeView()
            } else if !biometrics.isAuthenticated && userStorage.EnableLogscreen {
                BiometricsLockView()
            } else if userStorage.ShowLoginView || userStorage.ApiKey.isEmpty {
                NavigationStack {
                    LoginView()
                }
                .appReadableWidth()
            } else {
                TabbarView()
                    .id(userStorage.sessionID)
                    .tint(.orange)
                    .task(id: userStorage.ApiKey) { await runPushLogic() }
                    .sheet(isPresented: $showPushSetup, onDismiss: { registrar.setupClosed += 1 }) {
                        NavigationStack { PushSetupView() }.tint(.orange).appReadableWidth()
                    }
                    // Skipped / done in another window: close this window's copy too.
                    .onChange(of: registrar.setupClosed) {
                        if !PushSetupStore.shouldShow(apiKey: session.apiKey) { showPushSetup = false }
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if !networkMonitor.isConnected {
                            Label("Offline · Showing previously loaded data", systemImage: "wifi.slash")
                                .font(.footnote)
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(.thinMaterial)
                        }
                    }
            }
        }
        .alert("Secure storage unavailable", isPresented: Binding(
            get: { userStorage.storageError != nil },
            set: { if !$0 { userStorage.storageError = nil } }
        )) {
            Button("OK", role: .cancel) { userStorage.storageError = nil }
        } message: {
            Text(userStorage.storageError ?? "")
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Opening the app clears the badge (counter kept by the Notification Service Extension)
                // and removes its notifications from Notification Center.
                UserStorage.sharedDefault?.set(0, forKey: "BADGE_COUNT")
                UNUserNotificationCenter.current().setBadgeCount(0)
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                userStorage.InAppSwitcher = false
                // Retries the account id too: the first lookup may have failed offline.
                Task { await registrar.ensureAccountId(); nodes.syncWithCloud() }
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
        // Closed in another window (LAST_BUILD_NUMBER is shared): close this window's copy too.
        .onChange(of: userStorage.LAST_BUILD_NUMBER) { _, build in
            if build == Bundle.main.buildNumber {
                showWhatsNew = false
                activeSheet = nil
            }
        }
        .sheet(item: $activeSheet) { item in
            showActiveSheet(item: item)
        }
        .screenshotProtected(userStorage.ScreenshotProtection)
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
