//
//  HelpView.swift
//  IPv64
//
//  Created by Sebastian Rank on 07.11.22.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.openURL) var openURL
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    
    var body: some View {
        VStack {
            Form() {
                Section("Hilfe") {
                    HStack(alignment: .center) {
                        Image(systemName: "circle.fill")
                            .resizable()
                            .scaledToFill()
                            .foregroundColor(.red)
                            .frame(width: 8, height: 8)
                        Text("A-Record stimmt nicht überein!")
                    }
                    .frame(alignment: .center)
                    HStack(alignment: .center) {
                        Image(systemName: "circle.fill")
                            .resizable()
                            .scaledToFill()
                            .foregroundColor(.green)
                            .frame(width: 8, height: 8)
                        Text("A-Record stimmt überein!")
                    }
                    .frame(alignment: .center)
                }
                Section("Was ist IPv64.net?") {
                    Text("**IPv64** ist natürlich kein neues Internet-Protokoll (64), sondern einfach eine deduplizierte Kurzform von IPv6 und IPv4. Auf der Seite von IPv64 findest du einen **Dynamischen DNS** Dienst (DynDNS) und viele weitere nützliche Tools für dein tägliches Interneterlebnis. \n\nMit dem **dynamischen DNS Dienst** von IPv64 kannst du dir kostenfreie Subdomains registrieren und nutzen. Das Update der Domain übernimmt voll automatisch dein eigener Router oder alternative Hardware / Software. \n\nÜber den Youtube Kanal RaspberryPi Cloud wirst du ganz sicher noch viel mehr über die Welt der IT kennenlernen dürfen.")
                    Button(action: {
                        openURL(URL(string: "https://www.youtube.com/c/RaspberryPiCloud")!)
                    }) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.red)
                            Text("YouTube")
                                .foregroundColor(.red)
                        }
                    }
                }
                Section("Kontakt") {
                    Text("Ein Produkt der Prox IT UG (haftungsbeschränkt). \n\n**Angaben gemäß § 5 TMG**\nProx IT UG (haftungsbeschränkt)\nAm Eisenstein 10\n45470 Mülheim an der Ruhr\n\n**Vertreten durch**\nDennis Schröder (Geschäftsführer)\n\nRegistergericht: Amtsgericht Duisburg\nRegisternummer: HRB 35106")
                    Button(action: {
                        openURL(URL(string: "mailto:info@ipv64.net")!)
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(Color("primaryText"))
                            Text("info@ipv64.net")
                                .tint(Color("primaryText"))
                        }
                    }
                    .foregroundColor(Color("primaryText"))
                }
                Section("Über diese App ") {
                    Text("Diese App ist mithilfe der Community von RaspberryPi Cloud entstanden. \nAlle Rechte vorbehalten, bei Dennis Schröder.")
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.versionNumber)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Über")
        }
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}
