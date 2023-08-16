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
    @AppStorage("AccountInfos") var accountInfosJson: String = ""
    @AppStorage("DomainResult") var listOfDomainsString: String = ""
    @AppStorage("AccountList") var accountListJson: String = ""
    @AppStorage("current_Tab") var selectedTab: Tab = .domains
    
    @Binding var showDomains: Bool
    
    @State var activeSheet: ActiveSheet? = nil
    @State var accountInfos = AccountInfo()
    
    @State private var popToRootTab: Tab = .other
    @State private var showPlaceholder = false
    @State private var showWhatsNew = false
    @State private var accountList: [Account] = []
    
    private var availableTabs: [Tab] {
        Tab.tabList()
    }
    
    var body: some View {
        tabBarView
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
                let sdtoken = SetupPrefs.readPreference(mKey: "DEVICETOKEN", mDefaultValue: "") as! String
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
    
    
    
    private var tabBarView: some View {
        TabView(selection: .init(get: {
            selectedTab
        }, set: { newTab in
            Task {
                if newTab == selectedTab {
                    /// Stupid hack to trigger onChange binding in tab views.
                    popToRootTab = .other
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        popToRootTab = selectedTab
                    }
                }
                
                selectedTab = newTab
                
                await HapticManager.shared.fireHaptic(of: .tabSelection)
                await SoundEffectManager.shared.playSound(of: .tabSelection)
            }
            
        })) {
            ForEach(availableTabs) { tab in
                tab.makeContentView(popToRootTab: $popToRootTab)
                    .redacted(reason: showPlaceholder ? .placeholder : .init())
                    .tabItem {
                        tab.label
                            .labelStyle(TitleAndIconLabelStyle())
                    }
                    .tag(tab)
            }
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
                    if (accountListJson.isEmpty) {
                        createAccountList()
                    }
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
            
            var tab: Tab = .other
            
            if (tabId == 1) {
                tab = .domains
            } else if (tabId == 2) {
                tab = .healthchecks
            } else if (tabId == 3) {
                tab = .integrations
            } else if (tabId == 4) {
                tab = .profile
            }
            
            selectedTab = tab
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
//                if (isBiometricEnabled) {
                    showPlaceholder = true
//                }
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
    
    fileprivate func createAccountList() {
        if (!accountInfosJson.isEmpty) {
            loadAccountInfos()
            do {
                let apikey = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
                let sdtoken = SetupPrefs.readPreference(mKey: "DEVICETOKEN", mDefaultValue: "") as! String
                
                let account = Account(ApiKey: apikey, AccountName: accountInfos.email, DeviceToken: sdtoken, Since: accountInfos.reg_date, Active: true)
                
                accountList.append(account)
                
                let jsonEncoder = JSONEncoder()
                let jsonData = try jsonEncoder.encode(accountList)
                let json = String(data: jsonData, encoding: String.Encoding.utf8)
                accountListJson = json!
            } catch let error {
                print(error)
            }
        }
    }
    
    fileprivate func loadAccountInfos() {
        do {
            let jsonDecoder = JSONDecoder()
            let jsonData = accountInfosJson.data(using: .utf8)
            accountInfos = try jsonDecoder.decode(AccountInfo.self, from: jsonData!)
        } catch let error {
            print(error)
        }
    }
}

#Preview {
    TabbView(showDomains: .constant(true))
}
