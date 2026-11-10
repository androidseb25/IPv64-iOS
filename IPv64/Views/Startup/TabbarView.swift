import SwiftUI

struct TabbarView: View {
    @AppStorage("CURRENT_TAB", store: UserStorage.sharedDefault) private var selectedTab: Tabs = .domain
    // shortcut: the node screens will write these two flags (a connected node with the cdn64 / dns64 module
    // active); until they exist both stay false and the bar shows Domains, Healthchecks, CDN64, More.
    @AppStorage("NODE_PROXY_ACTIVE", store: UserStorage.sharedDefault) private var proxyActive = false
    @AppStorage("NODE_DNS_ACTIVE", store: UserStorage.sharedDefault) private var dnsActive = false
    @State private var paths: [Tabs: NavigationPath] = [:]

    private var visibleTabs: [Tabs] { Tabs.tabList(proxyActive: proxyActive, dnsActive: dnsActive) }

    private var selection: Binding<Tabs> {
        Binding(get: { selectedTab }, set: { tab in
            if tab == selectedTab { paths[tab] = NavigationPath() }
            selectedTab = tab
        })
    }

    var body: some View {
        if #available(iOS 27.0, *) {
            // iPhone Duo: sidebar on the inner display.
            tabs.tabBarMinimizeBehavior(.onScrollDown).defaultTabBarPlacement(.sidebar)
        } else if #available(iOS 26.0, *) {
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
    }

    /// A tab that left the bar (module switched off, old stored value) falls back to its slot or to Domains.
    private func fixSelection() {
        guard !visibleTabs.contains(selectedTab) else { return }
        switch selectedTab {
        case .cdn where proxyActive: selectedTab = .proxy64
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

#Preview { TabbarView() }
