//
//  DomainView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct DomainView: View {
    
    @Binding var popToRootTab: Tabs
    @StateObject private var api = ApiService()
    
    @State private var domainResult: DomainResult = .empty
    @State var v4: MyIP = .emptyV4
    @State var v6: MyIP = .emptyV6
    
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
            ForEach("".v64domains(), id: \.self) { domain in
                let filtered = domainResult.subdomains.filter { $0.baseDomain == domain }
                if (!filtered.isEmpty) {
                    Section(domain) {
                        ForEach(filtered, id: \.fqdn) { subDomain in
                            DomainItemView(domain: subDomain)
                        }
                    }
                }
            }
        }
        .showLoading($api.isLoading)
        .navigationTitle(Tabs.domain.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            GetIp()
        }
        .onAppear {
            GetIp()
        }
    }
    
    private func GetDomains() {
        Task {
            if let res = await api.GetDomains() {
                domainResult = res
                domainResult.subdomains = domainResult.subdomains.map { domain in
                    var d = domain
                    d.ipv4 = v4.ip ?? "0.0.0.0"
                    d.ipv6 = v6.ip ?? "::"
                    return d
                }
            }
        }
    }
    
    private func GetIp(_ onlyV4: Bool = true) {
        Task {
            if let res = await api.GetMyIp(onlyV4) {
                if (onlyV4) {
                    v4 = res
                    GetIp(false)
                } else {
                    v6 = res
                    GetDomains()
                }
            } else {
                GetDomains()
            }
        }
    }
}

#Preview {
    DomainView(popToRootTab: .constant(.domain))
}
