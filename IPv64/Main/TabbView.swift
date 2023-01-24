//
//  TabView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI

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
            ProfilView()
                .redacted(reason: showPlaceholder ? .placeholder : .init())
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
                .tag(3)
        }
        .tint(Color("ip64_color"))
        .sheet(item: $activeSheet) { item in
            showActiveSheet(item: item)
        }
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            
            var lastBuildNumber = SetupPrefs.readPreference(mKey: "LASTBUILDNUMBER", mDefaultValue: "0") as! String
            var token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            
            if Int(lastBuildNumber) != Int(Bundle.main.buildNumber) && !token.isEmpty {
                withAnimation {
                    showWhatsNew = true
                    activeSheet = .whatsnew
                }
            }
        }
        .onOpenURL { url in
            print("URL")
            print(url)
            guard url.scheme == "ipv64", url.host == "tab", let tabId = Int(url.pathComponents[1])
            else {
                print("issue")
                return
            }
            print("open tab \(tabId)")
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
}

struct TabbView_Previews: PreviewProvider {
    static var previews: some View {
        TabbView(showDomains: .constant(true))
    }
}
