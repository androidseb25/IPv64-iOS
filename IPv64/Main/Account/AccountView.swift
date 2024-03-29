//
//  AccountView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI
import Toast

struct AccountView: View {
    
    @AppStorage("AccountInfos") var accountInfosJson: String = ""
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    @State var accountInfos: AccountInfo = AccountInfo()
    @State var showDynHash = false
    @State var showApiKey = false
    @State var showDevToken = false
    
    var body: some View {
        ZStack {
            VStack {
                let dateDate = dateDBFormatter.date(from: accountInfos.reg_date ?? "0001-01-01 00:00:00")
                let dateString = itemFormatter.string(from: dateDate ?? Date())
                let apiLimit = thousendSeperator.string(from: (accountInfos.account_class?.api_limit! ?? Int(0 as NSNumber)) as NSNumber)
                let apiUpdates = thousendSeperator.string(from: (accountInfos.api_updates ?? Int(0 as NSNumber)) as NSNumber)
                Form {
                    Section("") {
                        Group {
                            HStack {
                                Text("Account Status")
                                Spacer()
                                Text("Aktiviert")
                                    .foregroundColor(.green)
                            }
                            HStack {
                                Text("Account Klasse")
                                Spacer()
                                Text(accountInfos.account_class?.class_name ?? "")
                                    .foregroundColor(.yellow)
                            }
                            HStack {
                                Text("E-Mail")
                                Spacer()
                                Text(accountInfos.email ?? "")
                                    .foregroundColor(.gray)
                            }
                            HStack {
                                Text("Registriert seit")
                                Spacer()
                                Text(dateString)
                                    .foregroundColor(.gray)
                            }
                        }
                        Group {
                            let subDom = accountInfos.dyndns_subdomains ?? 0
                            let subDomMax = accountInfos.account_class?.dyndns_domain_limit ?? 0
                            HStack {
                                Text("Dyn Domains")
                                Spacer()
                                Text("\(subDom) / \(subDomMax)")
                                    .foregroundColor(GetColor(cur: subDom, max: subDomMax))
                            }
                            let mDomains = accountInfos.owndomains ?? 0
                            let mDomainsMax = accountInfos.account_class?.owndomain_limit ?? 0
                            HStack {
                                Text("Domains")
                                Spacer()
                                Text("\(mDomains) / \(mDomainsMax)")
                                    .foregroundColor(GetColor(cur: mDomains, max: mDomainsMax))
                            }
                            let dynUp = accountInfos.dyndns_updates ?? 0
                            let dynUpMax = accountInfos.account_class?.dyndns_update_limit ?? 0
                            HStack {
                                Text("DynDNS Update Limit / 24h")
                                Spacer()
                                Text("\(dynUp) / \(dynUpMax)")
                                    .foregroundColor(GetColor(cur: dynUp, max: dynUpMax))
                            }
                        }
                        Group {
                            let health = accountInfos.healthchecks ?? 0
                            let healthMax = accountInfos.account_class?.healthcheck_limit ?? 0
                            HStack {
                                Text("Healthchecks")
                                Spacer()
                                Text("\(health) / \(healthMax)")
                                    .foregroundColor(GetColor(cur: health, max: healthMax))
                            }
                            let healthup = accountInfos.healthchecks_updates ?? 0
                            let healthupMax = accountInfos.account_class?.healthcheck_update_limit ?? 0
                            HStack {
                                Text("Healthcheck Updates")
                                Spacer()
                                Text("\(healthup) / \(healthupMax)")
                                    .foregroundColor(GetColor(cur: healthup, max: healthupMax))
                            }
                            HStack {
                                Text("API Limit / 24h")
                                Spacer()
                                Text("\(apiUpdates ?? "0") / \((apiLimit == "0" ? "∞" : apiLimit) ?? "0")")
                                    .foregroundColor(GetColor(cur: accountInfos.api_updates ?? 0, max: accountInfos.account_class?.api_limit ?? 0))
                            }
                            let sms = accountInfos.sms_count ?? 0
                            let smsMax = accountInfos.account_class?.sms_limit ?? 0
                            HStack {
                                Text("SMS Limit")
                                Spacer()
                                Text("\(sms) / \(smsMax)")
                                    .foregroundColor(GetColor(cur: sms, max: smsMax))
                            }
                        }
                        Group {
                            Button(action: {
                                withAnimation {
                                    showDynHash.toggle()
                                }
                            }) {
                                HStack {
                                    if (showDynHash) {
                                        Text(accountInfos.update_hash ?? "HASH")
                                            .multilineTextAlignment(.trailing)
                                            .foregroundColor(.gray)
                                    } else {
                                        Text("DynDNS Updatehash")
                                        Spacer()
                                        Text("••••••")
                                            .foregroundColor(.gray)
                                    }
                                }
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
                                    UIPasteboard.general.string = accountInfos.update_hash ?? "HASH"
                                }) {
                                    Label("Kopieren", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
                            .tint(Color("primaryText"))
                            Button(action: {
                                withAnimation {
                                    showApiKey.toggle()
                                }
                            }) {
                                HStack {
                                    if (showApiKey) {
                                        Text(accountInfos.api_key ?? "API KEY")
                                            .multilineTextAlignment(.trailing)
                                            .foregroundColor(.gray)
                                    } else {
                                        Text("API Key")
                                        Spacer()
                                        Text("••••••")
                                            .foregroundColor(.gray)
                                    }
                                }
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
                                    UIPasteboard.general.string = accountInfos.api_key ?? "API KEY"
                                }) {
                                    Label("Kopieren", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
                            .tint(Color("primaryText"))
                        }
                    }
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
        .onAppear {
            GetAccountInfos()
        }
        .navigationTitle("Account Status")
    }
    
    fileprivate func GetAccountInfos() {
        Task {
            accountInfos = await api.GetAccountStatus() ?? AccountInfo()
            let status = accountInfos.status
            if (status == nil) {
                throw NetworkError.NoNetworkConnection
            }
            if (status!.contains("429") && accountInfos.email == nil) {
                activeSheet = .error
                errorTyp = ErrorTypes.tooManyRequests
            } else if (status!.contains("401")) {
                activeSheet = .error
                errorTyp = ErrorTypes.unauthorized
            } else {
                let jsonEncoder = JSONEncoder()
                let jsonData = try jsonEncoder.encode(accountInfos)
                let json = String(data: jsonData, encoding: String.Encoding.utf8)
                accountInfosJson = json!
            }
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: .constant(false))
                .interactiveDismissDisabled(errorTyp?.status == 202 ? false : true)
                .onDisappear {
                    if (errorTyp?.status == 401) {
                        SetupPrefs.setPreference(mKey: "APIKEY", mValue: "")
                    } else {
                        GetAccountInfos()
                    }
                }
        default:
            EmptyView()
        }
    }
    
    fileprivate func GetColor(cur: Int, max: Int) -> Color {
        
        if (cur == max) {
            return .red
        }
        
        return .green
    }
    
    private let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView()
    }
}
