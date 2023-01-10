//
//  LoginView.swift
//  IPv64
//
//  Created by Sebastian Rank on 06.11.22.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var api: NetworkServices = NetworkServices()
    
    @State var username = ""
    @State var apiKey = ""
    @State var showMainView = false
    @State var loginFailed = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ScrollView {
                    VStack {
                        
                        Image("ipv64_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                            .padding(.bottom, 20)
                        
                        /*TextField("Benutzername", text: $username)
                            .font(.system(.body, design: .rounded))
                            .padding(EdgeInsets(top: 20.5, leading: 16, bottom: 20.5, trailing: 0))
                            .background(Color("textFieldBG")).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))*/
                        TextField("API - Key", text: $apiKey)
                            .font(.system(.body, design: .rounded))
                            .padding(EdgeInsets(top: 20.5, leading: 16, bottom: 20.5, trailing: 0))
                            .background(Color("textFieldBG")).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.top, 6)
                        Button(action: {
                            withAnimation {
                                loginFailed = false
                                SetupPrefs.setPreference(mKey: "APIKEY", mValue: apiKey)
                                showMainView.toggle()
                                Task {
                                    /*let apiUser = ApiUser(AU_Username: username, AU_APIKEY: apiKey)
                                    let result = await api.Login(user: apiUser)
                                    if (result != nil) {
                                        let r = result!
                                        if (r.User != nil) {
                                            SetupPrefs.setPreference(mKey: "APIKEY", mValue: r.User?.AU_APIKEY)
                                            SetupPrefs.setPreference(mKey: "ISLOGGEDIN", mValue: true)
                                            showMainView.toggle()
                                        } else {
                                            loginFailed.toggle()
                                        }
                                    }*/
                                }
                            }
                        }) {
                            Text("Login")
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
                                Text("Login fehlgeschlagen!")
                                    .font(.system(.body, design: .rounded, weight: .bold))
                                    .foregroundColor(.red)
                            } else {
                                Text("Login fehlgeschlagen!")
                                    .font(.system(.body, design: .rounded).bold())
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .frame(width: UIDevice.isIPhone ? geometry.size.width : geometry.size.width / 1.75, height: geometry.size.height)
                }
                .frame(maxWidth: .infinity)
                if api.isLoading {
                    VStack() {
                        Spinner(isAnimating: true, style: .large, color: .white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3).ignoresSafeArea())
                }
            }
        }
        .fullScreenCover(isPresented: $showMainView) {
            TabbView()
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
