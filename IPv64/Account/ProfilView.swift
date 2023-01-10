//
//  ProfilView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI

struct ProfilView: View {
    @Environment(\.openURL) var openURL
    
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
                        Button(action: {
                            openURL(URL(string: "https://discord.gg/rpicloud")!)
                        }) {
                            Text("Discord")
                        }
                    }
                }
                .navigationTitle("Account")
            }
            .accentColor(Color("AccentColor"))
        }
    }
}

struct ProfilView_Previews: PreviewProvider {
    static var previews: some View {
        ProfilView()
    }
}
