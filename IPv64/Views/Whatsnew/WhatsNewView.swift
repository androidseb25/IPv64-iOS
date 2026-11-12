//
//  WhatsNewView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 13.02.26.
//

import SwiftUI
import Combine

struct WhatsNewView: View {
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var userStorage = UserStorage.shared
    @Binding var activeSheet: ActiveSheet?
    @Binding var isPresented: Bool
    var isFromSetting = false
    
    var whatsNewList: [WhatsNew] = [
        WhatsNew(imageName: "bolt.heart", title: "Healthchecks 2.0".localized, subtitle: "Checks from several locations with status, statistics, incidents and events. Create and edit them right in the app.".localized),
        WhatsNew(imageName: "point.3.connected.trianglepath.dotted", title: "Nodes".localized, subtitle: "Link your Node64 or connect directly in your network: live status, modules, logs and commands.".localized),
        WhatsNew(imageName: "arrow.left.arrow.right", title: "Proxy64 & CDN64".localized, subtitle: "Manage the proxy hosts of your node and make them reachable from the internet with CDN64.".localized),
        WhatsNew(imageName: "server.rack", title: "DNS64".localized, subtitle: "Ad and tracker blocking on your node: pause it, see statistics, the live query log and local DNS records.".localized),
        WhatsNew(imageName: "chart.xyaxis.line", title: "Monitor64".localized, subtitle: "The hosts your node monitors, with charts, services and open problems, now in Healthchecks.".localized),
        WhatsNew(imageName: "bell.badge", title: "Push notifications".localized, subtitle: "Encrypted push notifications via SecNtfy and notification channels instead of integrations.".localized),
        WhatsNew(imageName: "square.grid.2x2", title: "Widgets & Control Center".localized, subtitle: "The Healthchecks widget in every size, a DNS64 widget with chart and pause, and a DNS64 switch in Control Center.".localized),
        WhatsNew(imageName: "ellipsis.circle", title: "More".localized, subtitle: "API keys, account links, IP lookup, password check and the honeypot network.".localized)
    ]
    
    var body: some View {
        VStack {
            VStack {
                Text("What's new?")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("In the version \(Bundle.main.versionNumber) (\(Bundle.main.buildNumber)) are these changes implemented and bugs have been resolved:")
                    .font(.system(.body, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.top, 1)
            }
            .padding(.vertical, 27.5)
            
            ScrollView {
                ForEach(whatsNewList, id: \.id) { item in
                    WhatsNewItemView(whatsNewItem: item)
                }
            }.offset(y: -10)
            
            Button(action: {
                withAnimation {
                    let buildNumber = Bundle.main.buildNumber
                    userStorage.LAST_BUILD_NUMBER = buildNumber
                    activeSheet = nil
                    dismiss()
                }
            }) {
                Text(isFromSetting ? "Close" : "Continue").font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 50, idealHeight: 50, maxHeight: 50, alignment: .center)
                    .background(.orange)
                    .cornerRadius(8.0)
            }
            .padding(.horizontal, 27.5)
            .padding(.bottom, UIDevice.isIpad ? 27.5 : 8)
            
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(!isFromSetting)
    }
}

@available(iOS 26.0, *)
struct WhatsNewView26: View {
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var userStorage = UserStorage.shared
    @Binding var activeSheet: ActiveSheet?
    @Binding var isPresented: Bool
    var isFromSetting = false
    
    var whatsNewList: [WhatsNew] = [
        WhatsNew(imageName: "bolt.heart", title: "Healthchecks 2.0".localized, subtitle: "Checks from several locations with status, statistics, incidents and events. Create and edit them right in the app.".localized),
        WhatsNew(imageName: "point.3.connected.trianglepath.dotted", title: "Nodes".localized, subtitle: "Link your Node64 or connect directly in your network: live status, modules, logs and commands.".localized),
        WhatsNew(imageName: "arrow.left.arrow.right", title: "Proxy64 & CDN64".localized, subtitle: "Manage the proxy hosts of your node and make them reachable from the internet with CDN64.".localized),
        WhatsNew(imageName: "server.rack", title: "DNS64".localized, subtitle: "Ad and tracker blocking on your node: pause it, see statistics, the live query log and local DNS records.".localized),
        WhatsNew(imageName: "chart.xyaxis.line", title: "Monitor64".localized, subtitle: "The hosts your node monitors, with charts, services and open problems, now in Healthchecks.".localized),
        WhatsNew(imageName: "bell.badge", title: "Push notifications".localized, subtitle: "Encrypted push notifications via SecNtfy and notification channels instead of integrations.".localized),
        WhatsNew(imageName: "square.grid.2x2", title: "Widgets & Control Center".localized, subtitle: "The Healthchecks widget in every size, a DNS64 widget with chart and pause, and a DNS64 switch in Control Center.".localized),
        WhatsNew(imageName: "ellipsis.circle", title: "More".localized, subtitle: "API keys, account links, IP lookup, password check and the honeypot network.".localized)
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("What's new in IPv64.net \nv\(Bundle.main.versionNumber) (\(Bundle.main.buildNumber))")
                .font(.system(.title3, weight: .bold))
                .padding(.bottom)
            
            ScrollView {
                ForEach(whatsNewList, id: \.id) { item in
                    WhatsNewItemView26(whatsNewItem: item)
                }
            }
            
            Button (action: {
                withAnimation {
                    let buildNumber = Bundle.main.buildNumber
                    userStorage.LAST_BUILD_NUMBER = buildNumber
                    activeSheet = nil
                    dismiss()
                }
            }) {
                Text(isFromSetting ? "Close" : "Continue")
                    .font(.system(.callout))
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(16)
            }
            .glassEffect(.regular.tint(.orange).interactive(true))
        }
        .padding([.top, .horizontal], 50)
        .interactiveDismissDisabled(!isFromSetting)
    }
}

#Preview {
    VStack { }
        .sheet(item: .constant(ActiveSheet.whatsnew)) { _ in
            if #available(iOS 26.0, *) {
                WhatsNewView26(activeSheet: .constant(nil), isPresented: .constant(true))
            } else {
                WhatsNewView(activeSheet: .constant(nil), isPresented: .constant(true))
            }
        }
}
