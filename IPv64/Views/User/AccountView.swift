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
            
            // Rows and texts as in Android 2.1.0 (AccountView).
            Section("Account") {
                labeled("Username", badge: me?.username?.nonBlank ?? String(localized: "none"), color: .gray)
                labeled("Account Plan", badge: me?.plan?.name?.nonBlank ?? String(localized: "none"), color: .yellow)
                labeled("Plan valid until", badge: planValidUntil, color: .gray)
                labeled("E-Mail", badge: me?.email?.nonBlank ?? String(localized: "none"), color: .gray)
                labeled("Registered since", badge: dateText(me?.registeredAt), color: .gray)
                labeled("Last login", badge: dateText(me?.lastLoginAt), color: .gray)
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
            
            Section("Failover") {
                quota("Failover Policies", usage?.failoverPolicies)
                quota("Failover Monitors", usage?.failoverMonitors)
                quota("Failover Rules", usage?.failoverRules)
            }

            Section("CDN") {
                quota("CDN Domains", usage?.cdnDomains)
                quota("CDN Traffic (GB)", usage?.cdnTrafficGB)
            }

            Section("VPN / DNS64") {
                labeled("VPN Traffic (GB)", badge: vpnTraffic, color: usage?.vpnTrafficGB?.limited == true ? .red : .green)
                quota("DNS64 Clients", usage?.dns64Clients)
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
                    Text(user.current?.Username ?? String(localized: "No User found"))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(user.current?.Information ?? String(localized: "No Information"))
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
    
    /// Android `formatGermanTime`, "none" when missing.
    private func dateText(_ date: Date?) -> String {
        date.map { DynDNSLogic.germanTime($0) } ?? String(localized: "none")
    }

    /// No plan: "–"; plan without end (free plan): "unlimited".
    private var planValidUntil: String {
        guard let plan = me?.plan else { return "–" }
        return plan.validUntil.map { DynDNSLogic.germanTime($0) } ?? String(localized: "unlimited")
    }

    /// Android `VpnTrafficUsage.usageText`: "used / limit", "(limit reached)" when limited, "–" without data.
    private var vpnTraffic: String {
        guard let q = usage?.vpnTrafficGB, let limit = q.limit else { return "–" }
        let text = "\((q.used ?? 0).formatted(.number.precision(.fractionLength(0...2)))) / \(limit.formatted())"
        return q.limited == true ? text + " (limit reached)" : text
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
    private func quota(_ title: LocalizedStringKey, _ q: Me.Quota?) -> some View {
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
    private func labeled(_ title: LocalizedStringKey, badge: String, color: Color? = nil) -> some View {
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
