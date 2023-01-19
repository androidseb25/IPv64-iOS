//
//  TabView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI

struct TabbView: View {
    
    @AppStorage("AccountInfos") var accountInfos: String = ""
    @AppStorage("DomainResult") var listOfDomainsString: String = ""
    
    @State var selectedView = 1
    
    var body: some View {
        TabView(selection: $selectedView) {
            ContentView()
                .tabItem {
                    Label("Domains", systemImage: "network")
                }
                .tag(1)
            HealthcheckView()
                .tabItem {
                    Label("Healthcheck", systemImage: "waveform.path.ecg")
                }
                .tag(2)
            ProfilView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
                .tag(3)
        }
        .tint(Color("ip64_color"))
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
}

struct TabbView_Previews: PreviewProvider {
    static var previews: some View {
        TabbView()
    }
}
