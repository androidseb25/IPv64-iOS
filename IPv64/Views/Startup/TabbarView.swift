import SwiftUI

struct TabbarView: View {
    @AppStorage("CURRENT_TAB", store: UserStorage.sharedDefault) private var selectedTab: Tabs = .domain
    @Environment(ConnectedNodes.self) private var nodes
    @Environment(\.scenePhase) private var scenePhase
    @State private var paths: [Tabs: NavigationPath] = [:]

    private var visibleTabs: [Tabs] { Tabs.tabList(proxyActive: nodes.proxyActive, dnsActive: !nodes.dnsIds.isEmpty) }

    private var selection: Binding<Tabs> {
        Binding(get: { selectedTab }, set: { tab in
            if tab == selectedTab { paths[tab] = NavigationPath() }
            selectedTab = tab
        })
    }

    var body: some View {
        // No default sidebar placement: on iPhone (also landscape) always the tab bar.
        if #available(iOS 26.0, *) {
            tabs.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: selection) {
            ForEach(visibleTabs) { tab in
                Tab(tab.labelNew, systemImage: tab.iconName, value: tab) { root(tab) }
            }
        }
        // Tab bar on iPhone, tab bar or sidebar on iPad, following the available width.
        .tabViewStyle(.sidebarAdaptable)
        .onAppear(perform: fixSelection)
        .onChange(of: visibleTabs) { fixSelection() }
        // The view is rebuilt per account (`.id(sessionID)`), so this re-reads the nodes of the new account.
        .task { nodes.refresh() }
        .task(id: nodes.ids) { await nodes.refreshModules() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await nodes.refreshModules() } }
        }
    }

    /// A tab that left the bar (module switched off, old stored value) falls back to its slot or to Domains.
    private func fixSelection() {
        guard !visibleTabs.contains(selectedTab) else { return }
        switch selectedTab {
        case .cdn where nodes.proxyActive: selectedTab = .proxy64
        case .proxy64: selectedTab = .cdn
        case .account, .notification, .dns64: selectedTab = .settings
        default: selectedTab = .domain
        }
    }

    private func root(_ tab: Tabs) -> some View {
        NavigationStack(path: Binding(get: { paths[tab] ?? NavigationPath() }, set: { paths[tab] = $0 })) {
            tab.makeContentView(popToRootTab: .constant(.other))
        }
    }
}

typealias TabbarView18 = TabbarView

#Preview { TabbarView().environment(ConnectedNodes()) }
