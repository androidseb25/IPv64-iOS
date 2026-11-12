//
//  AccountView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI
import IPv64

struct AccountView: View {
    
    @Environment(\.colorScheme) var systemColorScheme
    
    @Binding var popToRootTab: Tabs
    
    @StateObject private var userStorage = UserStorage.shared
    @Environment(Session.self) private var session
    @State private var me: Me?
    @State private var isLoading = false
    @State private var error: ErrorText?
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
                labeled("Account Plan", badge: me?.plan?.name?.nonBlank ?? "none", color: .yellow)
                labeled("E-Mail", badge: me?.email?.nonBlank ?? "none", color: .gray)
                labeled("Registered since", badge: registeredSince, color: .gray)
            }
            
            Section("DynDNS") {
                quota("Own Domain", usage?.ownDomains)
                quota("DynDNS Domains", usage?.dyndnsDomains)
                quota("DynDNS Update Limit / 24h", usage?.dyndnsUpdates24h)
            }
            
            Section("Healthcheck") {
                quota("Healthchecks", usage?.healthchecks)
                quota("Healthchecks Updates / 24h", usage?.healthcheckPings24h)
                quota("SMS Limit / 24h", usage?.sms24h)
            }
            
            Section("API") {
                HStack {
                    Text("API Key")
                    Spacer()
                    Text("swipe")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button {
                        Clipboard.copy(userStorage.ApiKey, sensitive: true)
                    } label: {
                        Label("Copy", systemImage: "document.on.document")
                    }
                    .tint(.blue)
                    .labelStyle(.iconOnly)
                }
            }
        }
        .showLoading(.constant(isLoading))
        .errorAlert($error)
        .navigationTitle(Tabs.account.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showUserSheet.animation()) {
            UserView().onDisappear {
                Task { await load() }
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
    
    private var usage: Me.Usage? { me?.usage }
    
    private var registeredSince: String {
        me?.registeredAt?.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(Locale(identifier: "de_DE"))) ?? "01.01.0001"
    }
    
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await ipv64Retrying { try await session.api.account.me() }
            if !Task.isCancelled { me = result }
        } catch {
            if !Task.isCancelled { self.error = ErrorText(error) }
        }
    }
    
    /// "used / limit", ∞ without limit; green below 70 %, yellow below 90 %, otherwise red.
    private func quota(_ title: String, _ q: Me.Quota?) -> some View {
        let used = Int(q?.used ?? 0)
        let text: String
        var color = Color.green
        if let limit = q?.limit, limit > 0 {
            text = "\(used.formatted()) / \(limit.formatted())"
            let ratio = Double(used) / Double(limit)
            color = ratio < 0.7 ? .green : ratio < 0.9 ? .yellow : .red
        } else {
            text = "\(used.formatted()) / ∞"
        }
        return labeled(title, badge: text, color: color)
    }
    
    @ViewBuilder
    private func labeled(_ title: String, badge: String, color: Color? = nil) -> some View {
        LabeledContent(title) {
            Text(badge)
                .foregroundStyle(color ?? .primary)
        }
    }
}

#Preview {
    NavigationStack {
        AccountView(popToRootTab: .constant(.account))
    }
}
