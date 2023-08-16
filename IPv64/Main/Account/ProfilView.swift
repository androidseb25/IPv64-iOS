//
//  ProfilView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI
import Introspect

struct ProfilView: View {
    
    @AppStorage("AccountInfos") var accountInfos: String = ""
    @AppStorage("DomainResult") var listOfDomainsString: String = ""
    @AppStorage("BIOMETRIC_ENABLED") var isBiometricEnabled: Bool = false
    @AppStorage("IntegrationList") var integrationListS: String = ""
    @AppStorage("HealthcheckList") var healthCheckList: String = ""
    @AppStorage("current_Tab") var selectedTab: Tab = .domains
    @AppStorage("AccountList") var accountListJson: String = ""
    
    @Environment(\.openURL) var openURL
    
    @Binding var popToRootTab: Tab
    
    @State var showLoginView = false
    @State var enableBio = false
    @State var accountList: [Account] = []
    @State var activeAccount: Account = Account()
    
    @State private var loadUser = false
    
    @ObservedObject private var bio = Biometrics()
    
    var body: some View {
        VStack {
            NavigationView {
                Form {
                    Section {
                        Button(action: {
                            
                        }) {
                            let dateDate = dateDBFormatter.date(from: activeAccount.Since ?? "0001-01-01 00:00:00")
                            let dateString = itemFormatter.string(from: dateDate ?? Date())
                            HStack {
                                VStack {
                                    Image(systemName: "person.circle")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundColor(Color("primaryText"))
                                }
                                .frame(width: 50, height: 50)
                                .cornerRadius(50)
                                VStack {
                                    Text(activeAccount.AccountName ?? "")
                                        .font(.system(.headline, design: .rounded))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(dateString)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(Color("accountSinceColor"))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.leading)
                            }
                            .redacted(reason: loadUser ? .placeholder : .init())
                        }
                    }
                    Section("Allgemein") {
                        NavigationLink("Account Status", destination: AccountView())
                        NavigationLink("Logs", destination: LogView())
                        NavigationLink("Meine IP", destination: IPView())
                    }
                    Section("Sicherheit") {
                        Button(action: { withAnimation { enableBio.toggle() } }) {
                            HStack {
                                Text("Bildschirmsperre \(enableBio ? "deaktivieren" : "aktivieren")")
                                Spacer()
                                Toggle("", isOn: $enableBio)
                                    .labelsHidden()
                                    .tint(Color("ip64_color"))
                                    .onChange(of: enableBio) { isBio in
                                        withAnimation {
                                            isBiometricEnabled = isBio
                                        }
                                    }
                            }
                        }
                        .tint(Color("primaryText"))
                    }
                    Section("Sonstiges") {
                        NavigationLink("Über", destination: HelpView())
                        Button(action: {
                            openURL(URL(string: "https://www.youtube.com/c/RaspberryPiCloud")!)
                        }) {
                            Text("YouTube")
                        }
                        .tint(Color("primaryText"))
                        Button(action: {
                            openURL(URL(string: "https://discord.gg/rpicloud")!)
                        }) {
                            Text("Discord")
                        }
                        .tint(Color("primaryText"))
                    }
                    Section {
                        Button(action: {
                            let apikey = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
                            var delAccountInd = accountList.firstIndex(where: { $0.ApiKey! == apikey})
                            
                            SetupPrefs.setPreference(mKey: "APIKEY", mValue: "")
                            SetupPrefs.setPreference(mKey: "LASTBUILDNUMBER", mValue: "0")
                            SetupPrefs.setPreference(mKey: "DEVICETOKEN", mValue: "")
                            accountInfos = ""
                            listOfDomainsString = ""
                            isBiometricEnabled = false
                            integrationListS = ""
                            healthCheckList = ""
                            selectedTab = .domains
                            withAnimation {
                                showLoginView.toggle()
                            }
                        }) {
                            Text("Logout")
                                .foregroundColor(.red)
                        }
                    }
                    .listRowBackground(Color.red.opacity(0.15))
                }
                .navigationTitle(Tab.profile.labelName)
                .onAppear {
                    enableBio = isBiometricEnabled
                    loadUser = true
                    if (!accountListJson.isEmpty) {
                        do {
                            let jsonDecoder = JSONDecoder()
                            let jsonData = accountListJson.data(using: .utf8)
                            accountList = try jsonDecoder.decode([Account].self, from: jsonData!)
                            activeAccount = accountList.first { $0.Active == true}!
                        } catch {
                            print("ERROR \(error.localizedDescription)")
                        }
                        loadUser = false
                    } else {
                        activeAccount = Account(ApiKey: "", AccountName: "Need to be Init!", DeviceToken: "", Since: "", Active: true)
                        loadUser = false
                    }
                }
            }
            .introspectNavigationController { navigationController in
                navigationController.splitViewController?.preferredPrimaryColumnWidthFraction = 1
                navigationController.splitViewController?.maximumPrimaryColumnWidth = 400
            }
            .accentColor(Color("AccentColor"))
        }
        .fullScreenCover(isPresented: $showLoginView) {
            LoginView()
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
    ProfilView(popToRootTab: .constant(.other))
}
