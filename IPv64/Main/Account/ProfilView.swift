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
    @AppStorage("SelectedView") var selectedView: Int = 1
    
    @Environment(\.openURL) var openURL
    
    @State var showLoginView = false
    @State var enableBio = false
    @ObservedObject private var bio = Biometrics()
    
    var body: some View {
        VStack {
            NavigationView {
                Form {
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
                            SetupPrefs.setPreference(mKey: "APIKEY", mValue: "")
                            SetupPrefs.setPreference(mKey: "LASTBUILDNUMBER", mValue: "0")
                            SetupPrefs.setPreference(mKey: "DEVICETOKEN", mValue: "")
                            accountInfos = ""
                            listOfDomainsString = ""
                            isBiometricEnabled = false
                            integrationListS = ""
                            healthCheckList = ""
                            selectedView = 1
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
                .navigationTitle("Account")
                .onAppear {
                    enableBio = isBiometricEnabled
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
}

struct ProfilView_Previews: PreviewProvider {
    static var previews: some View {
        ProfilView()
    }
}
