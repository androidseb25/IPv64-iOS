//
//  HealthcheckView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct HealthcheckView: View {
    
    @Binding var popToRootTab: Tabs
    @StateObject private var api = ApiService()
    
    var body: some View {
        NavigationStack {
            if #available(iOS 26.0, *) {
                listView
                //                    .setColorGradient((showAccount || showServerMap) ? .clear : .orange)
                    .setColorGradient(.orange)
            } else {
                listView
            }
        }
    }
    
    private var listView: some View {
        List {
//            ForEach(response64.cloudrouter, id: \.vrf_id) { router in
//                Section(router.name) {
//                    ForEach(router.gw, id: \.id) { gw in
//                        NavigationLink(destination: PeerView(gw: gw)) {
//                            TunnelItemView(gw: gw)
//                        }
//                    }
//                }
//            }
        }
        .showLoading($api.isLoading)
        .navigationTitle(Tabs.healthcheck.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
//            GetResponse64()
        }
        .onAppear {
//            GetResponse64()
//            vpnManager.loadManager()
        }
    }
}
#Preview {
    HealthcheckView(popToRootTab: .constant(.healthcheck))
}
