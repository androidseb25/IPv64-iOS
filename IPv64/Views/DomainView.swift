//
//  DomainView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct DomainView: View {
    
    @Environment(\.colorScheme) var systemColorScheme
    
    @Binding var popToRootTab: Tabs
    @StateObject private var api = ApiService()
    @StateObject private var userStorage = UserStorage.shared
    
    @State private var domainResult: DomainResult = .empty
    @State var v4: MyIP = .emptyV4
    @State var v6: MyIP = .emptyV6
    
    @State private var showNewDomainSheet: Bool = false
    @State private var isDomainChanged: Bool = false
    
    @State private var alertType: AlertType?
    @State private var apiErrorMessage: String = ""
    
    var body: some View {
        NavigationStack {
            if #available(iOS 26.0, *) {
                listView
                    .setColorGradient(showNewDomainSheet ? .clear : .orange)
            } else {
                listView
            }
        }
    }
    
    private var listView: some View {
        List {
            ForEach("".v64domains(), id: \.self) { domain in
                let filtered = domainResult.subdomains.filter { $0.baseDomain == domain }
                if (!filtered.isEmpty) {
                    Section(domain) {
                        ForEach(filtered.sorted(by: \.fqdn), id: \.fqdn) { subDomain in
                            NavigationLink(value: subDomain) {
                                DomainItemView(domain: subDomain)
                                .tag(subDomain.fqdn)
                            }
                        }
                    }
                }
            }
        }
        .showLoading($api.isLoading)
        .navigationTitle(Tabs.domain.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Domain.self) { domain in
            DomainDetailView(domain: domain, isChanged: $isDomainChanged)
        }
        .toolbar {
            ToolbarItem {
                Button(action: {
                    withAnimation {
                        showNewDomainSheet.toggle()
                    }
                }){
                    Label("Add", image: "network.badge.plus")
                }
                .tint(systemColorScheme == .dark ? .white : .black)
            }
        }
        .refreshable {
            GetIp()
        }
        .onAppear {
            if (isDomainChanged || userStorage.IsInitDomain) {
                isDomainChanged = false
                userStorage.IsInitDomain = false
                GetIp()
            }
        }
        .sheet(isPresented: $showNewDomainSheet.animation()){
            DomainNewView(isChanged: $isDomainChanged).onDisappear {
                if (isDomainChanged) {
                    isDomainChanged = false
                    GetIp()
                }
            }
        }
        .alert(item: $alertType) { type in
            switch type {
            case .apiError:
                return Alert(title: Text("Something went wrong."), message: Text("Something went wrong with the API. Please try again later. \n\n\(apiErrorMessage)"), dismissButton: .cancel(Text("OK")))
            default:
                return Alert(title: Text(""))
            }
        }
    }
    
    private func GetDomains() {
        Task {
            if var res = await api.GetDomains() {
                if (res.status.contains("200")) {
                    res.subdomains = res.subdomains.map { domain in
                        var d = domain
                        d.ipv4 = v4.ip ?? "0.0.0.0"
                        d.ipv6 = v6.ip ?? "::"
                        return d
                    }
                    domainResult = res
                } else {
                    apiErrorMessage = "\(res.status)\n\(res.info)"
                    alertType = .apiError
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
