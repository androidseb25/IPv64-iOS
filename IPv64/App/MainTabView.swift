import SwiftUI

/// Tab shell (spec 01 §1.2): DynDNS, Healthchecks, CDN64/Proxy64, DNS64 (only with a DNS64 node), More.
/// Also hosts the root effects of spec 01 §2.4 (node refresh triggers, automatic push setup).
struct MainTabView: View {
    @Environment(Session.self) private var session
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(PushRegistrar.self) private var registrar
    @Environment(\.scenePhase) private var scenePhase

    @State private var selected: AppTab = .dynDNS
    @State private var routers = TabRouters()
    /// Android rememberSaveable state: once per account / API key per app session.
    @State private var pushSetupTriggeredFor: String?
    @State private var tokenSyncedFor: String?
    @State private var showPushSetup = false

    var body: some View {
        TabView(selection: $selected) {
            tab(.dynDNS) { DomainListView() }
            tab(.healthchecks) { HealthcheckListView() }
            tab(.cdn) { CdnRootView() }
            if !nodes.dnsIds.isEmpty {
                tab(.dns64) { NodeDnsView() }
            }
            tab(.more) { MoreView() }
        }
        .tabViewStyle(.sidebarAdaptable)
        .appSidebarTabPlacement()
        .onChange(of: nodes.dnsIds) {
            if selected == .dns64 && nodes.dnsIds.isEmpty { selected = .more }
        }
        .onChange(of: selected) { nodes.refresh() }
        // Module state: on start and whenever the connected ids change …
        .task(id: nodes.ids) { await nodes.refreshModules() }
        // … and when the app returns to the foreground (module toggled in the node web UI).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await nodes.refreshModules() } }
        }
        .task(id: PushTrigger(tab: selected, atRoot: routers[selected].isAtRoot,
                              locked: session.isLocked, keyHash: PushSetupStore.keyHash(apiKey: session.apiKey))) {
            await runPushLogic()
        }
        .fullScreenCover(isPresented: $showPushSetup) {
            NavigationStack { PushSetupView() }
                .environment(routers[.more])
        }
    }

    private func tab<Root: View>(_ tab: AppTab, @ViewBuilder root: @escaping () -> Root) -> some TabContent<AppTab> {
        Tab(tab.title(proxyActive: nodes.proxyActive), systemImage: tab.systemImage(proxyActive: nodes.proxyActive), value: tab) {
            TabContainer(router: routers[tab],
                         placeholderTitle: tab.title(proxyActive: nodes.proxyActive),
                         placeholderImage: tab.systemImage(proxyActive: nodes.proxyActive),
                         root: root)
        }
    }

    /// Spec 01 §2.4 push logic; restarted on every route / lock / key change.
    private func runPushLogic() async {
        guard !session.isLocked, routers[selected].isAtRoot else { return }
        let apiKey = session.apiKey
        if let keyHash = PushSetupStore.keyHash(apiKey: apiKey), tokenSyncedFor != keyHash {
            tokenSyncedFor = keyHash
            // Background, errors swallowed: once per API key per session.
            Task {
                await registrar.ensureAccountId()
                _ = try? await registrar.syncTokenIfChanged(channels: nil)
            }
        }
        guard PushSetupStore.shouldShow(apiKey: apiKey) else { return }
        await registrar.ensureAccountId()
        guard !Task.isCancelled, PushSetupStore.shouldShow(apiKey: apiKey),
              let account = PushSetupStore.scope(apiKey: apiKey),
              pushSetupTriggeredFor != account else { return }
        pushSetupTriggeredFor = account
        showPushSetup = true
    }
}

private struct PushTrigger: Equatable {
    let tab: AppTab
    let atRoot: Bool
    let locked: Bool
    let keyHash: String?
}

/// One router per tab, kept for the lifetime of the tab shell.
final class TabRouters {
    private let routers: [AppTab: Router] = Dictionary(
        uniqueKeysWithValues: AppTab.allCases.map { ($0, Router(usesSplitView: $0.usesSplitView)) })

    subscript(tab: AppTab) -> Router { routers[tab]! }
}
