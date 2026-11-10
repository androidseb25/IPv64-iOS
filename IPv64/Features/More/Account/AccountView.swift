import SwiftUI
import IPv64

/// "Account" (spec 01 §3.7): account data of the active key, plan usage and the masked API key.
struct AccountView: View {
    @Environment(Session.self) private var session

    @State private var me: Me?
    @State private var isLoading = false
    @State private var error: ErrorText?

    var body: some View {
        List {
            if let account = session.accounts.current {
                Section {
                    NavigationLink(value: Route.accountDetails) {
                        ListRow(verbatim: account.username, subtitle: account.displayInformation,
                                systemImage: "person.crop.circle")
                    }
                }
            }
            if let me {
                content(me)
            }
        }
        .environment(\.appNativeList, true)
        .refreshable { await load() }
        .navigationTitle("Account")
        .loadingOverlay(isLoading && me == nil)
        .privacyProtected()
        .task(id: session.accountRevision) { await load() }
        .errorAlert($error) { Task { await load() } }
    }

    @ViewBuilder
    private func content(_ me: Me) -> some View {
        let none = String(localized: "none")
        let usage = me.usage
        InfoGroup("Account", rows: [
            InfoItem("Username", value: me.username ?? none),
            InfoItem("Account Plan", value: me.plan?.name ?? none),
            InfoItem("Plan valid until", value: me.plan.map {
                Formatters.germanTime($0.validUntil, fallback: String(localized: "unlimited"))
            } ?? "–"),
            InfoItem("E-Mail", value: me.email ?? none),
            InfoItem("Registered since", value: Formatters.germanTime(me.registeredAt, fallback: none)),
            InfoItem("Last login", value: Formatters.germanTime(me.lastLoginAt, fallback: none)),
        ])
        InfoGroup("DynDNS", rows: [
            InfoItem("Own Domain", value: Formatters.usageText(usage?.ownDomains)),
            InfoItem("DynDNS Domains", value: Formatters.usageText(usage?.dyndnsDomains)),
            InfoItem("DynDNS Update Limit / 24h", value: Formatters.usageText(usage?.dyndnsUpdates24h)),
        ])
        InfoGroup("Healthcheck", rows: [
            InfoItem("Healthchecks", value: Formatters.usageText(usage?.healthchecks)),
            InfoItem("Healthchecks Updates / 24h", value: Formatters.usageText(usage?.healthcheckPings24h)),
            InfoItem("SMS Limit / 24h", value: Formatters.usageText(usage?.sms24h)),
        ])
        InfoGroup("Failover", rows: [
            InfoItem("Failover Policies", value: Formatters.usageText(usage?.failoverPolicies)),
            InfoItem("Failover Monitors", value: Formatters.usageText(usage?.failoverMonitors)),
            InfoItem("Failover Rules", value: Formatters.usageText(usage?.failoverRules)),
        ])
        InfoGroup("CDN", rows: [
            InfoItem("CDN Domains", value: Formatters.usageText(usage?.cdnDomains)),
            InfoItem("CDN Traffic (GB)", value: Formatters.usageText(usage?.cdnTrafficGB)),
        ])
        InfoGroup("VPN / DNS64", rows: [
            InfoItem("VPN Traffic (GB)", value: Formatters.usageText(usage?.vpnTrafficGB)),
            InfoItem("DNS64 Clients", value: Formatters.usageText(usage?.dns64Clients)),
        ])
        InfoGroup("API", rows: [
            InfoItem("API Key", value: session.apiKey, copyable: true, sensitive: true, monospaced: true),
        ])
    }

    /// `account.me()` without cache and without retry (Android `ipv64Request`).
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            me = try await session.api.account.me()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }
}
