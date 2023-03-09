//
//  TabView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI
import FirebaseMessaging

struct TabbView: View {
    
    @AppStorage("BIOMETRIC_ENABLED") var isBiometricEnabled: Bool = false
    @AppStorage("AccountInfos") var accountInfos: String = ""
    @AppStorage("DomainResult") var listOfDomainsString: String = ""
    @AppStorage("SelectedView") var selectedView: Int = 1
    
    @Binding var showDomains: Bool
    @State private var showPlaceholder = false
    @State var activeSheet: ActiveSheet? = nil
    @State private var showWhatsNew = false
    
    var body: some View {
        TabView(selection: $selectedView) {
            ContentView()
                .redacted(reason: showPlaceholder ? .placeholder : .init())
                .tabItem {
                    Label("Domains", systemImage: "network")
                }
                .tag(1)
            HealthcheckView()
                .redacted(reason: showPlaceholder ? .placeholder : .init())
                .tabItem {
                    Label("Healthcheck", systemImage: "waveform.path.ecg")
                }
                .tag(2)
            IntegrationView()
                .redacted(reason: showPlaceholder ? .placeholder : .init())
                .tabItem {
                    Label("Integrationen", systemImage: "bell.and.waveform")
                }
                .tag(3)
            ProfilView()
                .redacted(reason: showPlaceholder ? .placeholder : .init())
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
                .tag(4)
        }
        .tint(Color("ip64_color"))
        .sheet(item: $activeSheet) { item in
            showActiveSheet(item: item)
        }
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            
            UIApplication.shared.applicationIconBadgeNumber = 0
            SetupPrefs.setPreference(mKey: "BADGE_COUNT", mValue: 0)
            
            var lastBuildNumber = SetupPrefs.readPreference(mKey: "LASTBUILDNUMBER", mDefaultValue: "0") as! String
            var token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            
            if Int(lastBuildNumber) != Int(Bundle.main.buildNumber) && !token.isEmpty {
                withAnimation {
                    showWhatsNew = true
                    activeSheet = .whatsnew
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                sendFCMToken()
            }
        }
        .onOpenURL { url in
            print("URL")
            guard url.scheme == "ipv64", url.host == "tab", let tabId = Int(url.pathComponents[1])
            else {
                print("issue")
                return
            }
            selectedView = tabId
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("Moving to the background! didBecomeActiveNotification")
            withAnimation {
                showPlaceholder = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("Moving to the background! willResignActiveNotification")
            withAnimation {
                if (isBiometricEnabled) {
                    showPlaceholder = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            print("Moving to the background! willTerminateNotification")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("Moving to the background! willEnterForegroundNotification")
            withAnimation {
                showPlaceholder = false
                showDomains = false
                
                UIApplication.shared.applicationIconBadgeNumber = 0
                SetupPrefs.setPreference(mKey: "BADGE_COUNT", mValue: 0)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            withAnimation {
                //                    if UIDevice.current.userInterfaceIdiom == .pad {
                /*DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                 _ = Functions().getGridCount(width: geo!.size.width, gridItem: $columnsGrid)
                 }*/
                //                    }
            }
        }
    }
    
    @ViewBuilder
    private func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .whatsnew:
            WhatsNewView(activeSheet: $activeSheet, isPresented: $showWhatsNew)
        default:
            EmptyView()
        }
    }
    
    private func sendFCMToken() {
        Messaging.messaging().isAutoInitEnabled = true
        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error fetching FCM registration token: \(error)")
            } else if let token = token {
                print("FCM registration token: \(token)")
                print(UIDevice().type.rawValue)
                let os = ProcessInfo().operatingSystemVersion
                var sdtoken = SetupPrefs.readPreference(mKey: "DEVICETOKEN", mDefaultValue: "") as! String
                if (sdtoken != token) {
                    Task {
                        let api = NetworkServices()
                        let result = await api.PostAddIntegration(integrationType: "mobil", dtoken: token, dName: UIDevice().type.rawValue)
                        SetupPrefs.setPreference(mKey: "DEVICETOKEN", mValue: token)
                    }
                }
            }
        }
    }
}

struct TabbView_Previews: PreviewProvider {
    static var previews: some View {
        TabbView(showDomains: .constant(true))
    }
}
