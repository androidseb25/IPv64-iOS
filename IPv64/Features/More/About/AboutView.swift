import SwiftUI

/// "About" (spec 04 §14): static texts.
struct AboutView: View {
    var body: some View {
        List {
            Section("Help") {
                help("IP differs", "The A or AAAA record doesn't match your current IP.", .ipv64Red)
                help("IP matches", "The A and AAAA records match your current IP.", .ipv64Green)
                help("IP unknown", "Your current IP couldn't be determined.", .ipv64Gray)
                help("No IP", "The domain has no A or AAAA record yet.", .ipv64Gray)
            }
            Section("What is IPv64.net?") {
                Text("IPv64 is of course not a new Internet Protocol (64), but simply a deduplicated short form of IPv6 and IPv4. On the IPv64 site you will find a Dynamic DNS service (DynDNS) and many other useful tools for your daily internet experience.\n\nWith the dynamic DNS service of IPv64 you can register and use free subdomains. The update of the domain is done automatically by your own router or alternative hardware / software. Besides updating IP addresses, simple Let's Encrypt DNS challenges are also possible.\n\nOwn domains can be added and benefit from all IPv64.net features like DynDNS services, GEO load balancing, DDoS protection, DynDNS2 and SSL encryption.")
            }
            Section("Contact") {
                Text("IPv64.net - A product of Prox IT UG (limited liability)\n\nInformation according to Section § 5 DDG\nProx IT UG (limited liability)\nAm Eisenstein 10\n45470 Mülheim an der Ruhr\n\nRepresented by\nDennis Schröder (CEO)\n\nRegistry court: Amtsgericht Duisburg\nRegister number: HRB 35106\nUst-IdNr.: DE350434683")
                    .textSelection(.enabled)
            }
            Section("About the App") {
                Text("This app was created with the help of the Raspberry Pi Cloud community. All rights reserved by Dennis Schröder.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func help(_ title: LocalizedStringKey, _ text: LocalizedStringKey, _ color: Color) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "circle.fill").foregroundStyle(color)
        }
    }
}
