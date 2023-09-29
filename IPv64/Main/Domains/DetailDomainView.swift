//
//  DetailDomainView.swift
//  IPv64
//
//  Created by Sebastian Rank on 07.11.22.
//

import SwiftUI
import Toast

struct DetailDomainView: View {
    
    @AppStorage("AccountInfos") var accountInfosJson: String = ""
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    @State var domainName: String
    @State var domain: Domain
    @State var myIp: MyIP
    @State var showingPopover = false
    @State var popOverValue = ""
    @State var isFromDNSRecord = false
    @State var accountInfos = AccountInfo()
    
    @State var delDNSRecord: RecordInfos? = nil
    @Binding var deleteThisDNSRecord: Bool
    
    fileprivate func deleteDNSRecord() {
        errorTyp = ErrorTypes.deleteDNSRecord
        activeSheet = .error
    }
    
    fileprivate func CheckIfIpCorrect() -> Bool {
        let firstRec = domain.records?.first(where: { $0.type == "A" })
        if (firstRec?.content != myIp.ip) {
            return false
        }
        return true
    }
    
    fileprivate func loadAccountInfos() {
        do {
            let jsonDecoder = JSONDecoder()
            let jsonData = accountInfosJson.data(using: .utf8)
            accountInfos = try jsonDecoder.decode(AccountInfo.self, from: jsonData!)
        } catch let error {
            print(error)
        }
    }
    
    fileprivate func GetAccountUpdateUrl() -> String {
        return "https://ipv64.net/update.php?key=" + accountInfos.update_hash! + "&domain=" + domainName
    }
    
    fileprivate func GetDomainUpdateUrl() -> String {
        return "https://ipv64.net/update.php?key=" + domain.domain_update_hash!
    }
    
    var body: some View {
        ZStack {
            Form {
                if (!CheckIfIpCorrect()) {
                    Section("Hinweis") {
                        Text("Dein A-Record stimmt mit deiner aktuellen IP nicht überein! Dies kann an einer Aktiven Mobilfunkverbindung hängen oder an die IP ist eine Serveradresse.")
                            .font(.system(.callout))
                        Button(action: {
                            Task {
                                do {
                                    if (accountInfos.update_hash == nil) {
                                        print("updatehash == nil");
                                        return
                                    }
                                    let result = try await api.UpdateDomainIp(updateKey: accountInfos.update_hash!, domain: domainName)
                                    if (result == nil) {
                                        throw NetworkError.NoNetworkConnection
                                    }
                                    if (result?.info == "Update Cooldown - 10sec") {
                                        activeSheet = .error
                                        errorTyp = ErrorTypes.updateCoolDown
                                        return
                                    }
                                    withAnimation {
                                        deleteThisDNSRecord = true
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                } catch let error {
                                    print(error)
                                    activeSheet = .error
                                    errorTyp = ErrorTypes.websiteRequestError
                                }
                            }
                            print("Aktualisiere A-Record")
                        }) {
                            Text("A-Record aktualisieren?")
                                .foregroundColor(.blue)
                                .font(.system(.callout))
                        }
                    }
                }
                Section("Allgemein") {
                    HStack {
                        Text("Wildcard:")
                        Spacer()
                        Text(domain.wildcard! == 1 ? "ja" : "nein")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Updates:")
                        Spacer()
                        Text("\(domain.updates!)")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Account Update URL:")
                        Spacer()
                        Text(GetAccountUpdateUrl())
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .none, action: {
                            let toast = Toast.default(
                                image: GetUIImage(imageName: "doc.on.doc", color: UIColor.systemBlue, hierarichal: true),
                                title: "Kopiert!", config: .init(
                                    direction: .top,
                                    autoHide: true,
                                    enablePanToClose: false,
                                    displayTime: 4,
                                    enteringAnimation: .fade(alphaValue: 0.5),
                                    exitingAnimation: .slide(x: 0, y: -100))
                            )
                            toast.show(haptic: .success)
                            UIPasteboard.general.string = GetAccountUpdateUrl()
                        }) {
                            Label("Kopieren", systemImage: "doc.on.doc")
                        }
                        .tint(.blue)
                    }
                    HStack {
                        Text("Domain Update URL:")
                        Spacer()
                        Text(GetDomainUpdateUrl())
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .none, action: {
                            let toast = Toast.default(
                                image: GetUIImage(imageName: "doc.on.doc", color: UIColor.systemBlue, hierarichal: true),
                                title: "Kopiert!", config: .init(
                                    direction: .top,
                                    autoHide: true,
                                    enablePanToClose: false,
                                    displayTime: 4,
                                    enteringAnimation: .fade(alphaValue: 0.5),
                                    exitingAnimation: .slide(x: 0, y: -100))
                            )
                            toast.show(haptic: .success)
                            UIPasteboard.general.string = GetDomainUpdateUrl()
                        }) {
                            Label("Kopieren", systemImage: "doc.on.doc")
                        }
                        .tint(.blue)
                    }
                }
                
                ForEach(domain.records!.sorted { $0.type!.lowercased() < $1.type!.lowercased() }, id: \.record_id) { record in
                    let dateDate = dateDBFormatter.date(from: record.last_update!)
                    let dateString = itemFormatter.string(from: dateDate ?? Date())
                    let ttlState = thousendSeperator.string(from: record.ttl! as NSNumber)
                    
                    RecordItemView(record: record, ttlState: ttlState!, dateString: dateString)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive, action: {
                                delDNSRecord = record
                                deleteDNSRecord()
                            }) {
                                Label("Löschen", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
            }
            .onAppear {
                loadAccountInfos()
            }
            .navigationTitle(domainName)
            .toolbar {
                ToolbarItem {
                    Button(action: {
                        activeSheet = .adddns
                    }) {
                        Image(systemName: "square.and.pencil")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(Color("primaryText"))
                    }
                    .foregroundColor(.black)
                }
            }
            .sheet(item: $activeSheet) { item in
                showActiveSheet(item: item)
            }
            if api.isLoading {
                VStack() {
                    Spinner(isAnimating: true, style: .large, color: .white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3).ignoresSafeArea())
            }
        }
    }
    
    private let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    private let dateDBFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    private let thousendSeperator: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter
    }()
    
    struct RecordItemView : View {
        
        @State var record: RecordInfos
        @State var ttlState: String
        @State var dateString: String
        
        var body: some View {
            Section("\(record.type!)") {
                HStack {
                    Text("Präfix:")
                    Spacer()
                    Text(record.praefix!.count == 0 ? "---" : record.praefix!)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("TTL:")
                    Spacer()
                    Text(ttlState)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("Typ:")
                    Spacer()
                    Text(record.type!)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("Wert:")
                    Spacer()
                    Text(record.content!)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("letzte Änderung:")
                    Spacer()
                    Text(dateString)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .adddns:
            NewDomainDNSView(isSaved: $isFromDNSRecord, domainName: domainName).onDisappear {
                if (isFromDNSRecord) {
                    deleteThisDNSRecord = true
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: $deleteThisDNSRecord)
                .interactiveDismissDisabled(errorTyp?.status == 202 ? false : true)
                .onDisappear {
                    if (deleteThisDNSRecord) {
                        Task {
                            let res = await api.DeleteDNSRecord(recordId: (delDNSRecord?.record_id)!)
                            
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
                            
                            
                            withAnimation {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }
        default:
            EmptyView()
        }
    }
}

struct DetailDomainView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DetailDomainView(domainName: "sebhaha.ipv64.de", domain: Domain(
                updates: 0,
                wildcard: 1,
                records: [
                    RecordInfos(
                        record_id: 4900,
                        content: "2a02:26f7:ec48:6609:0:a054:3b9d:dcc4",
                        ttl: 3600,
                        type: "AAAA",
                        praefix: "",
                        last_update: "2022-10-28 21:57:34"
                    )
                ]
            ), myIp: MyIP(ip: "0.0.0.0"), deleteThisDNSRecord: .constant(false))
        }.preferredColorScheme(.light)
        
        NavigationView {
            DetailDomainView(domainName: "sebhaha.ipv64.de", domain: Domain(
                updates: 0,
                wildcard: 1,
                records: [
                    RecordInfos(
                        record_id: 4900,
                        content: "2a02:26f7:ec48:6609:0:a054:3b9d:dcc4",
                        ttl: 3600,
                        type: "AAAA",
                        praefix: "",
                        last_update: "2022-10-28 21:57:34"
                    )
                ]
            ), myIp: MyIP(ip: "0.0.0.0"), deleteThisDNSRecord: .constant(false))
        }.preferredColorScheme(.dark)
    }
}
