//
//  AccountListView.swift
//  IPv64
//
//  Created by Sebastian Rank on 28.09.23.
//

import SwiftUI

struct AccountListView: View {
    @AppStorage("AccountList") var accountListJson: String = ""
    @AppStorage("DomainResult") var listOfDomainsString: String = ""
    @AppStorage("IntegrationList") var integrationListS: String = ""
    @AppStorage("HealthcheckList") var healthCheckList: String = ""
    
    @Environment(\.presentationMode) var presentationMode
    
    @Binding var isBottomSheetVisible: Bool
    @Binding var accountList: [Account]
    @Binding var newAccountB: Bool
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    @State private var selectedAccount: Account? = nil
    @State private var deleteAccount: Bool = false
    
    fileprivate func deleteAccountDialog() {
        errorTyp = ErrorTypes.deleteAccount
        activeSheet = .error
        print(errorTyp)
    }
    
    var body: some View {
        VStack {
            Form {
                Section("Deine Accounts") {
                    ForEach(accountList, id: \.ApiKey) { acc in
                        let dateDate = dateDBFormatter.date(from: acc.Since ?? "0001-01-01 00:00:00")
                        let dateString = itemFormatter.string(from: dateDate ?? Date())
                        Button(action: {
                            let beforeAccInt = accountList.firstIndex { $0.Active == true }
                            if (beforeAccInt! > -1) {
                                accountList[beforeAccInt!].Active = false
                            }
                            let currentAccInd = accountList.firstIndex { $0.ApiKey == acc.ApiKey }
                            if (currentAccInd! > -1) {
                                accountList[currentAccInd!].Active = true
                                SetupPrefs.setPreference(mKey: "APIKEY", mValue: accountList[currentAccInd!].ApiKey)
                            }
                            do {
                                let jsonEncoder = JSONEncoder()
                                let jsonData = try jsonEncoder.encode(accountList)
                                let json = String(data: jsonData, encoding: String.Encoding.utf8)
                                accountListJson = json!
                            } catch let error {
                                print(error)
                            }
                            listOfDomainsString = ""
                            integrationListS = ""
                            healthCheckList = ""
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: acc.Active! ? "checkmark.circle.fill" : "circle")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(Color("ip64_color"))
                                    .frame(width: 22, height: 22)
                                    .padding(.trailing)
                                VStack(alignment: .leading) {
                                    Text(acc.AccountName!)
                                        .foregroundStyle(Color("primaryText"))
                                    Text(dateString)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(Color("accountSinceColor"))
                                }
                                
                            }
                        }
                        .listRowBackground(acc.Active! ? Color("AccountSelectionBG") : Color("SectionBG"))
                        .swipeActions(edge: .trailing) {
                            if (!acc.Active!) {
                                Button(role: .destructive, action: {
                                    print("delete")
                                    selectedAccount = acc
                                    deleteAccountDialog()
                                }) {
                                    Label("Löschen", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
                Button(action: {
                    withAnimation {
                        newAccountB = true
                        isBottomSheetVisible = false
//                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color("ip64_color"))
                            .frame(width: 32, height: 32)
                            .padding(.trailing)
                        VStack(alignment: .leading) {
                            Text("Neuen Account hinzufügen")
                                .foregroundStyle(Color("primaryText"))
                        }
                        
                    }
                    .padding(.vertical, 10)
                }
            }
            .scrollIndicators(.hidden)
            .sheet(item: $activeSheet) { item in
                showActiveSheet(item: item)
            }
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: $deleteAccount)
                .interactiveDismissDisabled(errorTyp?.status == 202 ? false : true)
                .onDisappear {
                    do {
                        let jsonDecoder = JSONDecoder()
                        let jsonData = accountListJson.data(using: .utf8)
                        var accountList = try jsonDecoder.decode([Account].self, from: jsonData!)
                        
                        if (deleteAccount) {
                            print(selectedAccount)
                            let indSel = accountList.firstIndex { $0.ApiKey == selectedAccount?.ApiKey }
                            print(indSel)
                            if indSel! > -1 {
                                accountList.remove(at: indSel!)
                            }
                            self.accountList = accountList
                            
                            let jsonEncoder = JSONEncoder()
                            let jsonData = try jsonEncoder.encode(accountList)
                            let json = String(data: jsonData, encoding: String.Encoding.utf8)
                            accountListJson = json!
                        }
                    } catch let error {
                        print(error)
                    }
                }
        default:
            EmptyView()
        }
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
}

#Preview {
    AccountListView(isBottomSheetVisible: .constant(false), accountList: .constant([]), newAccountB: .constant(false))
}
