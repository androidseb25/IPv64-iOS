//
//  IPView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI

struct IPView: View {
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var myIP: MyIP = MyIP(ip: "")
    @State var myIPV6: MyIP = MyIP(ip: "")
    
    var body: some View {
        VStack {
            VStack {
                Text("IPv4:")
                if (myIP.ip?.count == 0) {
                    Spinner(isAnimating: true, style: .medium, color: .white)
                } else {
                    Text(myIP.ip!)
                        .lineLimit(1)
                        .minimumScaleFactor(0.01)
                        .font(.system(.title, design: .rounded).bold())
                        .frame(maxWidth: .infinity)
                        .padding(10)
                }
            }
            VStack {
                Text("IPv6:")
                if (myIPV6.ip?.count == 0) {
                    Spinner(isAnimating: true, style: .medium, color: .white)
                } else {
                    Text(myIPV6.ip!)
                        .lineLimit(1)
                        .minimumScaleFactor(0.01)
                        .font(.system(.title, design: .rounded).bold())
                        .frame(maxWidth: .infinity)
                        .padding(10)
                }
            }
        }
        .padding(10)
        .onAppear {
            Task {
                myIP = await api.GetMyIP() ?? MyIP(ip: "0.0.0.0")
                myIPV6 = await api.GetMyIPV6() ?? MyIP(ip: "0.0.0.0")
            }
        }
        .navigationTitle("Meine IP")
    }
}

struct IPView_Previews: PreviewProvider {
    static var previews: some View {
        IPView()
    }
}
