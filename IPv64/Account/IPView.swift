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
        
        Form {
            Section("IPv4") {
                if (myIP.ip?.count == 0) {
                    Spinner(isAnimating: true, style: .medium, color: .white)
                } else {
                    Text(myIP.ip!)
                        .lineLimit(1)
                        .minimumScaleFactor(0.01)
                        .swipeActions(edge: .trailing) {
                            Button(role: .none, action: {
                                UIPasteboard.general.string = myIP.ip! ?? "0.0.0.0"
                            }) {
                                Label("IPv4 kopieren", systemImage: "doc.on.doc")
                            }
                            .tint(.blue)
                        }
                }
            }
            Section("IPv6") {
                if (myIPV6.ip?.count == 0) {
                    Spinner(isAnimating: true, style: .medium, color: .white)
                } else {
                    Text(myIPV6.ip!)
                        .lineLimit(1)
                        .minimumScaleFactor(0.01)
                        .swipeActions(edge: .trailing) {
                            Button(role: .none, action: {
                                UIPasteboard.general.string = myIPV6.ip! ?? "0.0.0.0"
                            }) {
                                Label("IPv6 kopieren", systemImage: "doc.on.doc")
                            }
                            .tint(.blue)
                        }
                }
            }
        }
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
