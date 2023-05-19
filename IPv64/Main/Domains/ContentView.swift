//
//  ContentView.swift
//  IPv64
//
//  Created by Sebastian Rank on 06.11.22.
//

import SwiftUI
import CoreData
import Introspect
import Toast

struct ContentView: View {
    
    @AppStorage("AccountInfos") var accountInfos: String = ""
    @AppStorage("DomainResult") var listOfDomainsString: String = ""
    
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var myIP: MyIP = MyIP(ip: "")
    @State var myIPV6: MyIP = MyIP(ip: "")
    @State var listOfDomains: DomainResult = DomainResult()
    @State var listDomains: [DomainItems] = []
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
            api.isLoading = true
            if (isRefresh || listOfDomainsString.isEmpty) {
                Task {
                    let response = await api.GetDomains()
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
                    prepareToNormalList()
                }
            } else {
                let jsonDecoder = JSONDecoder()
                let jsonData = listOfDomainsString.data(using: .utf8)
                listOfDomains = try jsonDecoder.decode(DomainResult.self, from: jsonData!)
                
                prepareToNormalList()
            }
        } catch let error {
            print(error)
            activeSheet = .error
            errorTyp = ErrorTypes.websiteRequestError
        }
        loadIpAddress()
    }
    
    fileprivate func prepareToNormalList() {
        listDomains = []
        listOfDomains.subdomains?.forEach { domain in
            var isDomaindAdded = false
            dynDomainList.forEach { dynDomain in
                if (domain.key.contains(dynDomain)) {
                    var domInd = listDomains.firstIndex(where: { $0.name == dynDomain })
                    if (domInd == nil) {
                        var domval: Domain = domain.value
                        domval.name = domain.key
                        var dom = DomainItems(name: dynDomain, list: [domval])
                        listDomains.append(dom)
                    } else {
                        var domval: Domain = domain.value
                        domval.name = domain.key
                        listDomains[domInd!].list?.append(domval)
                    }
                    isDomaindAdded = true
                }
            }
            if (!isDomaindAdded) {
                var domInd = listDomains.firstIndex(where: { $0.name == "Eigene Domains" })
                if (domInd == nil) {
                    var domval: Domain = domain.value
                    domval.name = domain.key
                    var dom = DomainItems(name: "Eigene Domains", list: [domval])
                    listDomains.append(dom)
                } else {
                    var domval: Domain = domain.value
                    domval.name = domain.key
                    listDomains[domInd!].list?.append(domval)
                }
            }
        }
    }
    
    fileprivate func loadIpAddress() {
        api.isLoading = true
        Task {
            myIP = await api.GetMyIP() ?? MyIP(ip: "0.0.0.0")
            myIPV6 = await api.GetMyIPV6() ?? MyIP(ip: "0.0.0.0")
        }
    }
    
    fileprivate func SetDotColor(domain: Domain) -> Color {
        let firstRec = domain.records?.first(where: { $0.type == "A" })
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
    
    fileprivate func DomainViews() -> some View {
        return VStack {
            ZStack {
                NavigationView {
                    VStack {
                        Form {
                            if (listOfDomains.subdomains == nil) {
                                Section("Domainen") {
                                    Text("Keine Daten gefunden!")
                                }
                            } else {
                                let sortedList = listDomains.sorted { $0.name!.lowercased() < $1.name!.lowercased() }
                                ForEach(sortedList, id: \.id) { domain in
                                    
                                    let sorted = Array(domain.list!.sorted { $0.name.lowercased() < $1.name.lowercased() })
                                    Section(domain.name!) {
                                        ForEach(sorted, id: \.id) { dom in
                                            NavigationLink(destination: DetailDomainView(domainName: dom.name, domain: dom, myIp: myIP, deleteThisDNSRecord: $deleteThisDNSRecord ).onDisappear {
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
                                                        .foregroundColor(SetDotColor(domain: dom))
                                                        .frame(width: 8, height: 8)
                                                    Text(dom.name)
                                                }
                                                .frame(alignment: .center)
                                            }
                                            .swipeActions(edge: .trailing) {
                                                Button(role: .destructive, action: {
                                                    delDomain = dom.name
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
                if api.isLoading {
                    VStack() {
                        Spinner(isAnimating: true, style: .large, color: .white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3).ignoresSafeArea())
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            DomainViews()
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
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .add:
            NewDomainView(newItem: $isNewItem)
                .onDisappear {
                    if (isNewItem) {
                        isNewItem = false
                        listOfDomainsString = ""
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
                            let res = await api.DeleteDomain(domain: delDomain)
                            let status = res?.status
                            if (status == nil) {
                                throw NetworkError.NoNetworkConnection
                            }
                            if (status!.contains("429")) {
                                activeSheet = .error
                                errorTyp = ErrorTypes.tooManyRequests
                            } else if (status!.contains("401")) {
                                activeSheet = .error
                                errorTyp = ErrorTypes.unauthorized
                            } else {
                                activeSheet = nil
                                errorTyp = nil
                                let toast = Toast.default(
                                    image: GetUIImage(imageName: "checkmark.circle", color: UIColor.systemGreen, hierarichal: true),
                                    title: "Erfolgreich gelöscht!", config: .init(
                                        direction: .top,
                                        autoHide: true,
                                        enablePanToClose: false,
                                        displayTime: 4,
                                        enteringAnimation: .fade(alphaValue: 0.5),
                                        exitingAnimation: .slide(x: 0, y: -100))
                                )
                                toast.show(haptic: .success)
                            }
                            
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
