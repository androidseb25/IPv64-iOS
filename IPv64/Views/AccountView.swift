//
//  AccountView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct AccountView: View {
    
    @Environment(\.colorScheme) var systemColorScheme
    
    @Binding var popToRootTab: Tabs
    
    @StateObject private var userStorage = UserStorage.shared
    @StateObject private var api = ApiService()
    @State private var account: AccountInfo = .empty
    @State private var user: User = .empty
    @State private var showUserSheet = false
    
    var body: some View {
        if #available(iOS 26.0, *) {
            listView
                .setColorGradient(showUserSheet ? .clear : .orange)
        } else {
            listView
        }
    }
    
    private var listView: some View {
        List {
            accountSelectionView
            
            Section("Account") {
                labeled("Account Status", badge: account.AccountStatus, color: account.AccountStatusColor)
                labeled("Account Plan", badge: account.account_class.class_name.isEmpty ? "none" : account.account_class.class_name, color: .yellow)
                labeled("E-Mail", badge: account.email.isEmpty ? "none" : account.email, color: .gray)
                labeled("Registered since", badge: account.RegisteredSince, color: .gray)
            }
            
            Section("DynDNS") {
                labeled("Own Domain", badge: account.OwnDomainsUsageText, color: account.OwnDomainsUsageColor)
                labeled("DynDNS Domains", badge: account.DynDnsDomainUsageText, color: account.DynDnsDomainUsageColor)
                labeled("DynDNS Update Limit / 24h", badge: account.DynDnsUpdateUsageText, color: account.DynDnsUpdateUsageColor)
                HStack {
                    Text("DynDNS Updatehash")
                    Spacer()
                    Text("swipe")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button {
                        UIPasteboard.general.string = account.update_hash
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label("Copy", systemImage: "document.on.document")
                    }
                    .tint(.blue)
                }
            }
            
            Section("Healthcheck") {
                labeled("Healthchecks", badge: account.HealthcheckUsageText, color: account.HealthcheckUsageColor)
                labeled("Healthchecks Updates / 24h", badge: account.HealthcheckUpdateUsageText, color: account.HealthcheckUpdateUsageColor)
                labeled("SMS Limit / 24h", badge: account.SmsUsageText, color: account.SmsUsageColor)
            }
            
            Section("API") {
                labeled("API calls Limit / 24h", badge: account.ApiUsageText, color: account.ApiUsageColor)
                
                HStack {
                    Text("API Key")
                    Spacer()
                    Text("swipe")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button {
                        UIPasteboard.general.string = userStorage.ApiKey
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label("Copy", systemImage: "document.on.document")
                    }
                    .tint(.blue)
                }
            }
        }
        .showLoading($api.isLoading)
        .navigationTitle(Tabs.account.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let res = await api.GetAccountStatus() {
                account = res
            }
        }
        .sheet(isPresented: $showUserSheet.animation()) {
            UserView().onDisappear {
                Task {
                    if let res = await api.GetAccountStatus() {
                        account = res
                    }
                }
            }
        }
    }
    
    private var accountSelectionView: some View {
        Button(action: {
            withAnimation {
                showUserSheet.toggle()
            }
        }) {
            HStack {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 55, height: 55)
                VStack(alignment: .leading) {
                    Text(user.current?.Username ?? "No User found")
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(user.current?.Information ?? "No Information")
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal, 8)
            .foregroundStyle(systemColorScheme == .dark ? .white : .black)
        }
    }
    
    @ViewBuilder
    private func labeled(_ title: String, badge: String, color: Color? = nil) -> some View {
        Text(title)
            .badge(
                Text(badge)
                    .foregroundStyle(color ?? .primary)
            )
    }
}

#Preview {
    NavigationStack {
        AccountView(popToRootTab: .constant(.account))
    }
}
