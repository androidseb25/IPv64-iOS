import SwiftUI

struct TabbarView: View {
    @AppStorage("CURRENT_TAB", store: UserStorage.sharedDefault) private var selectedTab: Tabs = .domain
    @State private var paths: [Tabs: NavigationPath] = [:]

    private var selection: Binding<Tabs> {
        Binding(get: { selectedTab }, set: { tab in
            if tab == selectedTab { paths[tab] = NavigationPath() }
            selectedTab = tab
        })
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            tabs.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: selection) {
            ForEach(Tabs.tabList()) { tab in
                Tab(tab.labelNew, systemImage: tab.iconName, value: tab) { root(tab) }
            }
            if #available(iOS 26.0, *) {
                Tab(Tabs.account.labelNew, systemImage: Tabs.account.iconName, value: Tabs.account) {
                    root(.account)
                }
            }
        }
        .onAppear {
            if #unavailable(iOS 26.0), selectedTab == .account { selectedTab = .settings }
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
