//
//  ProfilView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI
import Introspect

struct ProfilView: View {
    
    @AppStorage("AccountInfos") var accountInfos: String = ""
    @AppStorage("DomainResult") var listOfDomainsString: String = ""
    
    @Environment(\.openURL) var openURL
    
    @State var showLoginView = false
    
    var body: some View {
        VStack {
            NavigationView {
                Form {
                    Section("Allgemein") {
                        NavigationLink("Account Status", destination: AccountView())
                        NavigationLink("Logs", destination: LogView())
                        NavigationLink("Meine IP", destination: IPView())
                    }
                    Section("Sonstiges") {
                        NavigationLink("Über", destination: HelpView())
                        Button(action: {
                            openURL(URL(string: "https://www.youtube.com/c/RaspberryPiCloud")!)
                        }) {
                            Text("YouTube")
                        }
                        .tint(Color("primaryText"))
                        Button(action: {
                            openURL(URL(string: "https://discord.gg/rpicloud")!)
                        }) {
                            Text("Discord")
                        }
                        .tint(Color("primaryText"))
                    }
                    Section {
                        Button(action: {
                            SetupPrefs.setPreference(mKey: "APIKEY", mValue: "")
                            accountInfos = ""
                            listOfDomainsString = ""
                            withAnimation {
                                showLoginView.toggle()
                            }
                        }) {
                            Text("Logout")
                                .foregroundColor(.red)
                        }
                    }
                    .listRowBackground(Color.red.opacity(0.15))
                }
                .navigationTitle("Account")
            }
            .introspectNavigationController { navigationController in
                navigationController.splitViewController?.preferredPrimaryColumnWidthFraction = 1
                navigationController.splitViewController?.maximumPrimaryColumnWidth = 400
            }
            .accentColor(Color("AccentColor"))
        }
        .fullScreenCover(isPresented: $showLoginView) {
            LoginView()
        }
    }
}

struct ProfilView_Previews: PreviewProvider {
    static var previews: some View {
        ProfilView()
    }
}
