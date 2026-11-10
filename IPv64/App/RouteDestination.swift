import SwiftUI

/// Maps every `Route` to its screen. Feature agents edit only their own cases' lines.
struct RouteDestination: View {
    let route: Route

    var body: some View {
        screen.appReadableWidth().appScreenBackground()
    }

    @ViewBuilder private var screen: some View {
        switch route {
        case .domainDetail(let name): DomainDetailView(name: name)
        case .domainSettings(let name): DomainSettingsView(name: name)
        case .recordEdit(let domain, let recordId): RecordEditView(domain: domain, recordId: recordId)

        case .healthcheckDetail(let token): HealthcheckDetailView(token: token)
        case .healthcheckForm(let token): HealthcheckFormView(token: token)
        case .nodeCheckDetail(let nodeId, let token): NodeCheckDetailView(nodeId: nodeId, token: token)
        case .nodeCheckEdit(let nodeId, let token): NodeCheckEditView(nodeId: nodeId, token: token)

        case .cdn: CdnView()
        case .cdnDetail(let token): CdnDetailView(token: token)
        case .cdnSettings(let token): CdnSettingsView(token: token)
        case .proxyHostEdit(let nodeId, let hostId): ProxyHostEditView(nodeId: nodeId, hostId: hostId)

        case .nodeDns(let nodeId): NodeDnsView(nodeId: nodeId)
        case .nodeDnsLog(let nodeId): NodeDnsLogView(nodeId: nodeId)
        case .nodeDnsRecords(let nodeId): NodeDnsRecordsView(nodeId: nodeId)

        case .account: AccountView()
        case .accountDetails: AccountDetailView()
        case .accountEdit(let accountId): AccountEditView(accountId: accountId)
        case .addAccount: LoginView(isFromUser: true)
        case .apiKeys: ApiKeysView()
        case .accountLinks: AccountLinksView()
        case .nodes: NodesView()
        case .nodeDetail(let nodeId): NodeDetailView(nodeId: nodeId)
        case .nodeModule(let nodeId, let module): NodeModuleView(nodeId: nodeId, module: module)
        case .channels: ChannelsView()
        case .channelNew: ChannelSetupView(channelId: nil)
        case .channelEdit(let id): ChannelSetupView(channelId: id)
        case .pushSetup: PushSetupView()
        case .notificationSettings: NotificationSettingsView()
        case .threatLookup(let ip): ThreatLookupView(ip: ip)
        case .passwordCheck: PasswordCheckView()
        case .honeypot: HoneypotView()
        case .logs: LogsView()
        case .about: AboutView()
        }
    }
}

/// Maps every shared `SheetRoute` to its sheet.
struct SheetDestination: View {
    let sheet: SheetRoute

    var body: some View {
        switch sheet {
        case .directAccess(let nodeId): NodeLocalSheet(nodeId: nodeId)
        }
    }
}
