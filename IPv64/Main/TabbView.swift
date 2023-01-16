//
//  TabView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI

struct TabbView: View {
    
    @State var selectedView = 1
    @State var activeSheet: ActiveSheet? = nil
    @State private var showWhatsNew = false
    
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
        .sheet(item: $activeSheet) { item in
            showActiveSheet(item: item)
        }
        .onAppear {
            let lastBuildNumber = SetupPrefs.readPreference(mKey: "LASTBUILDNUMBER", mDefaultValue: "0") as! String
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            if Int(lastBuildNumber) != Int(Bundle.main.buildNumber) && !token.isEmpty {
                withAnimation {
                    showWhatsNew = true
                    activeSheet = .whatsnew
                }
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
        TabbView()
    }
}
