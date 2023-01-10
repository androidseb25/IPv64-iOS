//
//  AccountView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI

struct AccountView: View {
    
    @AppStorage("AccountInfos") var accountInfosJson: String = ""
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var accountInfos: AccountInfo = AccountInfo()
    @State var showDynHash = false
    @State var showApiKey = false
    
    var body: some View {
        ZStack {
            VStack {
                let dateDate = dateDBFormatter.date(from: accountInfos.reg_date ?? "0001-01-01 00:00:00")
                let dateString = itemFormatter.string(from: dateDate ?? Date())
                let apiLimit = thousendSeperator.string(from: (accountInfos.account_class?.api_limit! ?? Int(0 as NSNumber)) as NSNumber)
                let apiUpdates = thousendSeperator.string(from: (accountInfos.api_updates! ?? Int(0 as NSNumber)) as NSNumber)
                Form {
                    Section("") {
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
                            Text((accountInfos.email)!)
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text("Registriert seit")
                            Spacer()
                            Text(dateString)
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text("Dyn Domains")
                            Spacer()
                            Text("0 / \(accountInfos.account_class?.dyndns_domain_limit ?? 0)")
                                .foregroundColor(.green)
                        }
                        HStack {
                            Text("Domains")
                            Spacer()
                            Text("0 / 1")
                                .foregroundColor(.green)
                        }
                        HStack {
                            Text("DynDNS Update Limit / 24h")
                            Spacer()
                            Text("\(accountInfos.dyndns_updates ?? 0) / \(accountInfos.account_class?.dyndns_update_limit ?? 0)")
                                .foregroundColor(.green)
                        }
                        HStack {
                            Text("API Limit / 24h")
                            Spacer()
                            Text("\(apiUpdates ?? "0") / \(apiLimit ?? "0")")
                                .foregroundColor(.green)
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
                                    UIPasteboard.general.string = accountInfos.update_hash ?? "HASH"
                                }) {
                                    Label("DynDNS Updatehash kopieren", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
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
                                    UIPasteboard.general.string = accountInfos.api_key ?? "API KEY"
                                }) {
                                    Label("API Key kopieren", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
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
            Task {
                accountInfos = await api.GetAccountStatus() ?? AccountInfo()
                print(accountInfos)
                let jsonEncoder = JSONEncoder()
                let jsonData = try jsonEncoder.encode(accountInfos)
                let json = String(data: jsonData, encoding: String.Encoding.utf8)
                accountInfosJson = json!
            }
        }
        .navigationTitle("Account Status")
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
