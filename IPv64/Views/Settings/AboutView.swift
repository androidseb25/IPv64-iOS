//
//  AboutView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct AboutView: View {
    
    @Binding var popToRootTab: Tabs
    
    var body: some View {
        if #available(iOS 26.0, *) {
            listView
                .setColorGradient(.orange)
        } else {
            listView
        }
    }
    
    private var listView: some View {
        List {
            Section("Help") {
                HStack {
                    Image(systemName: "circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(.red)
                        .padding(.trailing, 5)
                    Text("A-Record or AAAA-Record didn't match")
                        .multilineTextAlignment(.leading)
                }
                HStack {
                    Image(systemName: "circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(.green)
                        .padding(.trailing, 5)
                    Text("A-Record or AAAA-Record match")
                        .multilineTextAlignment(.leading)
                }
            }
            Section("What is IPv64.net?") {
                Text("IPv64 is of course not a new Internet Protocol (64), but simply a deduplicated short form of IPv6 and IPv4. On the IPv64 site you will find a Dynamic DNS service (DynDNS) and many other useful tools for your daily internet experience.\n\nWith the dynamic DNS service of IPv64 you can register and use free subdomains. The update of the domain is done automatically by your own router or alternative hardware / software. Besides updating IP addresses, simple Let's Encrypt DNS challenges are also possible.\n\nOwn domains can be added and benefit from all IPv64.net features like DynDNS services, GEO load balancing, DDoS protection, DynDNS2 and SSL encryption.")
            }
            Section("Contact") {
                Text("IPv64.net - A product of Prox IT UG (limited liability)\n\nInformation according to Section § 5 DDG\nProx IT UG (limited liability)\nAm Eisenstein 10\n45470 Mülheim an der Ruhr\n\nRepresented by\nDennis Schröder (CEO)\n\nRegistry court: Amtsgericht Duisburg\nRegister number: HRB 35106\nUst-IdNr.: DE350434683")
            }
            Section("About the App") {
                Text("This app was created with the help of the Raspberry Pi Cloud community. All rights reserved by Dennis Schröder.")
                Button(action: {
                    if let url = URL(string: "https://github.com/androidseb25") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Visit me on GitHub (androidseb25)")
                }
                Button(action: {
                    if let url = URL(string: "https://github.com/androidseb25/IPv64-iOS") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Visit the project on GitHub")
                }
            }
        }
        .navigationTitle(Tabs.about.labelNew)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView(popToRootTab: .constant(.domain))
    }
}
