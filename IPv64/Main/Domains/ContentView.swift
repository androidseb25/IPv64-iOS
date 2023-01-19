//
//  ContentView.swift
//  IPv64
//
//  Created by Sebastian Rank on 06.11.22.
//

import SwiftUI
import CoreData
import Introspect

struct ContentView: View {
    
    @AppStorage("AccountInfos") var accountInfos: String = ""
    @AppStorage("DomainResult") var listOfDomainsString: String = ""
    
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var myIP: MyIP = MyIP(ip: "")
    @State var myIPV6: MyIP = MyIP(ip: "")
    @State var listOfDomains: DomainResult = DomainResult()
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    @State var showSheet = false
    @State var delDomain = ""
    @State var deleteThisDomain = false
    @State var deleteThisDNSRecord: Bool = false
    @State var showLoginView = false
    @State private var isNewItem = false
    
    fileprivate func loadAccountInfos() {
        Task {
            do {
                let response = await api.GetAccountStatus()
                if (response == nil) {
                    throw NetworkError.NoNetworkConnection
                }
                let jsonEncoder = JSONEncoder()
                let jsonData = try jsonEncoder.encode(response)
                let json = String(data: jsonData, encoding: String.Encoding.utf8)
                accountInfos = json!
            } catch let error {
                print(error)
                activeSheet = .error
                errorTyp = ErrorTypes.websiteRequestError
            }
        }
    }
    
    fileprivate func loadDomains(isRefresh: Bool) {
        do {
            if (listOfDomainsString.isEmpty || isRefresh) {
                Task {
                    let response = await api.GetDomains()
                    print(response)
                    let status = response?.status
                    if (status == nil) {
                        throw NetworkError.NoNetworkConnection
                    }
                    if (status!.contains("429") && response?.subdomains == nil) {
                        activeSheet = .error
                        errorTyp = ErrorTypes.tooManyRequests
                    } else if (status!.contains("401")) {
                        activeSheet = .error
                        errorTyp = ErrorTypes.unauthorized
                    } else {
                        activeSheet = nil
                        errorTyp = nil
                        listOfDomains = response!
                    }
                    let jsonEncoder = JSONEncoder()
                    let jsonData = try jsonEncoder.encode(response)
                    let json = String(data: jsonData, encoding: String.Encoding.utf8)
                    listOfDomainsString = json!
                    //loadAccountInfos()
                    print(listOfDomains)
                }
            } else {
                let jsonDecoder = JSONDecoder()
                print(listOfDomainsString)
                let jsonData = listOfDomainsString.data(using: .utf8)
                listOfDomains = try jsonDecoder.decode(DomainResult.self, from: jsonData!)
            }
        } catch let error {
            print(error)
            activeSheet = .error
            errorTyp = ErrorTypes.websiteRequestError
        }
        loadIpAddress()
    }
    
    fileprivate func loadIpAddress() {
        Task {
            myIP = await api.GetMyIP() ?? MyIP(ip: "0.0.0.0")
            myIPV6 = await api.GetMyIPV6() ?? MyIP(ip: "0.0.0.0")
        }
    }
    
    fileprivate func SetDotColor(domain: Domain) -> Color {
        let firstRec = domain.records?.first(where: { $0.type == "A" })
        print(firstRec?.content)
        print(myIP.ip)
        print(firstRec?.content == myIP.ip)
        if (firstRec?.content == myIP.ip) {
            return .green
        }
        
        return .red
    }
    
    fileprivate func deleteDomain() {
        errorTyp = ErrorTypes.delete
        activeSheet = .error
        print(errorTyp)
    }
    
    fileprivate func extractedFunc() -> some View {
        return NavigationView {
            VStack {
                Form {
                    Section("Domainen") {
                        if (listOfDomains.subdomains == nil) {
                            Text("Keine Daten gefunden!")
                        } else {
                            ForEach(Array(listOfDomains.subdomains!.keys.sorted { $0.lowercased() < $1.lowercased() }), id: \.self) { domain in
                                let domainOb = listOfDomains.subdomains![domain]
                                NavigationLink(destination: DetailDomainView(domainName: domain, domain: domainOb!, myIp: myIP, deleteThisDNSRecord: $deleteThisDNSRecord ).onDisappear {
                                    if (deleteThisDNSRecord) {
                                        deleteThisDNSRecord = false
                                        presentationMode.wrappedValue.dismiss()
                                        loadDomains(isRefresh: true)
                                    }
                                }) {
                                    HStack(alignment: .center) {
                                        Image(systemName: "circle.fill")
                                            .resizable()
                                            .scaledToFill()
                                            .foregroundColor(SetDotColor(domain: domainOb!))
                                            .frame(width: 8, height: 8)
                                        Text(domain)
                                    }
                                    .frame(alignment: .center)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive, action: {
                                            delDomain = domain
                                            deleteDomain()
                                        }) {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }
                                    .tint(.red)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .refreshable {
                loadDomains(isRefresh: true)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            activeSheet = .add
                        }
                    }) {
                        Image(systemName: "plus.circle")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(Color("primaryText"))
                    }
                    .foregroundColor(.black)
                }
            }
            .navigationTitle("Domains")
        }
        .introspectNavigationController { navigationController in
            navigationController.splitViewController?.preferredPrimaryColumnWidthFraction = 1
            navigationController.splitViewController?.maximumPrimaryColumnWidth = 400
        }
        .accentColor(Color("AccentColor"))
    }
    
    var body: some View {
        ZStack {
            extractedFunc()
            if api.isLoading {
                VStack() {
                    Spinner(isAnimating: true, style: .large, color: .white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3).ignoresSafeArea())
            }
        }
        .sheet(item: $activeSheet) { item in
            showActiveSheet(item: item)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadDomains(isRefresh: false)
        }
        .fullScreenCover(isPresented: $showLoginView) {
            LoginView()
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .add:
            NewDomainView(newItem: $isNewItem)
                .onDisappear {
                    if (isNewItem) {
                        isNewItem = false
                        loadDomains(isRefresh: true)
                    }
                }
        case .help:
            HelpView()
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: $deleteThisDomain)
                .interactiveDismissDisabled(errorTyp?.status == 202 ? false : true)
                .onDisappear {
                    if (deleteThisDomain) {
                        Task {
                            print(delDomain)
                            let res = await api.DeleteDomain(domain: delDomain)
                            print(res)
                            loadDomains(isRefresh: true)
                        }
                    } else {
                        if (errorTyp?.status == 401) {
                            SetupPrefs.setPreference(mKey: "APIKEY", mValue: "")
                            withAnimation {
                                showLoginView.toggle()
                            }
                        } else {
                            loadDomains(isRefresh: false)
                        }
                    }
                }
        default:
            EmptyView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
