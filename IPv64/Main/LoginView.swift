//
//  LoginView.swift
//  IPv64
//
//  Created by Sebastian Rank on 06.11.22.
//

import SwiftUI

struct LoginView: View {
    
    @AppStorage("NEW_ACCOUNT") var newAccount = false
    @AppStorage("AccountInfos") var accountInfosJson: String = ""
    @AppStorage("AccountList") var accountListJson: String = ""
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    
    @State var actionSheet: ActiveSheet?
    @State var errorTyp: ErrorTyp? = nil
    @State var username = ""
    @State var apiKey = ""
    @State private var errorMsg = ""
    @State var showMainView = false
    @State var loginFailed = false
    @State var accountInfos = AccountInfo()
    @State private var accountList: [Account] = []
    
    var body: some View {
        GeometryReader { geometry in
            if (!showMainView) {
                ZStack {
                    ScrollView {
                        VStack {
                            Image("ipv64_logo_new")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color("lightgray")))
                                .padding(.bottom, 20)
                            
                            Button(action: {
                                withAnimation {
                                    actionSheet = .qrcode
                                }
                            }) {
                                Text("Login mit QR Code")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.bold)
                                    .textCase(.uppercase)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .padding(16)
                                    .foregroundColor(Color.white)
                                    .background(Color("ip64_color")).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .padding(.vertical)
                            
                            HStack {
                                VStack {}
                                    .frame(maxWidth: .infinity, maxHeight: 1)
                                    .background(Color.gray)
                                    .padding(.trailing, 16)
                                Text("ODER")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.bold)
                                    .textCase(.uppercase)
                                VStack {}
                                    .frame(maxWidth: .infinity, maxHeight: 1)
                                    .background(Color.gray)
                                    .padding(.trailing, 16)
                            }
                            .padding(.horizontal, 16)
                            
                            TextField("API - Key", text: $apiKey)
                                .font(.system(.body, design: .rounded))
                                .padding(EdgeInsets(top: 20.5, leading: 16, bottom: 20.5, trailing: 0))
                                .background(Color("textFieldBG")).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .padding(.top, 6)
                                .tint(Color("ip64_color"))
                            
                            Button(action: {
                                withAnimation {
                                    if (newAccount) {
                                        addNewAccount()
                                    } else {
                                        SetupPrefs.setPreference(mKey: "APIKEY", mValue: apiKey)
                                        showMainView.toggle()
                                    }
                                }
                            }) {
                                Text("Login mit API Key")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.bold)
                                    .textCase(.uppercase)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .padding(16)
                                    .foregroundColor(Color.white)
                                    .background(Color("ip64_color")).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .padding(.vertical)
                            
                            if (loginFailed) {
                                if #available(iOS 16.0, *) {
                                    Text("Login fehlgeschlagen!\n\(errorMsg)")
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                        .foregroundColor(.red)
                                } else {
                                    Text("Login fehlgeschlagen!\n\(errorMsg)")
                                        .font(.system(.body, design: .rounded).bold())
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding()
                        .frame(width: UIDevice.isIPhone ? geometry.size.width : geometry.size.width / 1.75, height: geometry.size.height)
                    }
                    .frame(maxWidth: .infinity)
                    .sheet(item: $actionSheet) { item in
                        showActiveSheet(item: item)
                    }
                    .onAppear {
                        if (!accountListJson.isEmpty) {
                            do {
                                let jsonDecoder = JSONDecoder()
                                let jsonData = accountListJson.data(using: .utf8)
                                accountList = try jsonDecoder.decode([Account].self, from: jsonData!)
                                print(accountList)
                            } catch {
                                print("ERROR \(error.localizedDescription)")
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
            } else {
                TabbView(showDomains: .constant(true))
            }
        }
    }
    
    @ViewBuilder
    private func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .qrcode:
            CodeScannerView(codeTypes: [.qr], simulatedData: "", completion: self.handleScan).edgesIgnoringSafeArea(.bottom)
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: .constant(false))
                .interactiveDismissDisabled(true)
                .onDisappear {
                    if (self.errorTyp!.status == 201) {
                        withAnimation {
                            errorTyp = nil
                            actionSheet = nil
                            newAccount = false
                            showMainView.toggle()
                            apiKey = ""
                        }
                    }
                }
        default:
            EmptyView()
        }
    }
    
    private func addNewAccount() {
        if (apiKey.isEmpty) {
            return;
        }
        
        let accountInd = accountList.firstIndex { $0.ApiKey == apiKey }
        if (accountInd != nil && accountInd != -1) {
            errorTyp = ErrorTypes.accountFound
            actionSheet = .error
        } else {
            Task {
                do {
                    await getAccountInfos()
                    
                    if (accountInfos.api_key == nil) {
                        errorTyp = ErrorTypes.accountNotFound
                        actionSheet = .error
                    } else {
                        
                        let sdtoken = SetupPrefs.readPreference(mKey: "DEVICETOKEN", mDefaultValue: "") as! String
                        
                        let result = await api.PostAddIntegration(integrationType: "mobil", dtoken: sdtoken, dName: UIDevice().type.rawValue, apiKey: apiKey)
                        
                        print(result)
                        
                        let account = Account(ApiKey: apiKey, AccountName: accountInfos.email, DeviceToken: sdtoken, Since: accountInfos.reg_date, Active: false)
                        
                        accountList.append(account)
                        
                        let jsonEncoder = JSONEncoder()
                        let jsonData = try jsonEncoder.encode(accountList)
                        let json = String(data: jsonData, encoding: String.Encoding.utf8)
                        accountListJson = json!
                        
                        actionSheet = .error
                        errorTyp = ErrorTypes.accountSuccessfullyAdded
                    }
                } catch let error {
                    print(error)
                }
            }
        }
    }
    
    private func handleScan(result: Result<String, CodeScannerView.ScanError>) {
        switch result {
        case .success(let data): do {
            apiKey = data
            loginFailed = false
            if (newAccount) {
                addNewAccount()
            } else {
                SetupPrefs.setPreference(mKey: "APIKEY", mValue: apiKey)
                showMainView.toggle()
                withAnimation {
                    self.actionSheet = nil
                }
            }
        } case .failure(let error): do {
            errorMsg = error.localizedDescription
            loginFailed = true
            withAnimation {
                self.actionSheet = nil
            }
        }}
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
    
    fileprivate func getAccountInfos() async {
        accountInfos = await api.GetAccountStatus(apiKey: apiKey) ?? AccountInfo()
        print(accountInfos)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .preferredColorScheme(.dark)
        LoginView()
            .preferredColorScheme(.light)
    }
}
