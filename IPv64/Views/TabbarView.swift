//
//  TabbarView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

@available(iOS 26.0, *)
struct TabbarView: View {
    
    @AppStorage("CURRENT_TAB", store: UserStorage.sharedDefault) var selectedTab: Tabs = .domain
    
    @State private var availableTabs: [Tabs] = []
    @State private var popToRootTab: Tabs = .other
    @State private var isQrSheetPresented = false
    
    var body: some View {
        TabView(selection: .init(get: {
            selectedTab
        }, set: { newTab in
            Task {
                withAnimation {
                    if newTab == selectedTab {
                        /// Stupid hack to trigger onChange binding in tab views.
                        popToRootTab = .other
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            popToRootTab = selectedTab
                        }
                    }
                    
                    selectedTab = newTab
                }
            }
        })) {
            ForEach(availableTabs) { tab in
                Tab(tab.labelNew, systemImage: tab.iconName, value: tab) {
                    NavigationStack {
                        tab.makeContentView(popToRootTab: $popToRootTab)
                    }
                }
            }
            Tab(Tabs.account.labelNew, systemImage: Tabs.account.iconName, value: Tabs.account, role: .search) {
                NavigationStack {
                    AccountView(popToRootTab: $popToRootTab)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onAppear {
            availableTabs = Tabs.tabList()
        }
    }
}

struct TabbarView18: View {
    
    @AppStorage("CURRENT_TAB", store: UserStorage.sharedDefault) var selectedTab: Tabs = .domain
    
    @State private var availableTabs: [Tabs] = []
    @State private var popToRootTab: Tabs = .other
    
    var body: some View {
        TabView(selection: .init(get: {
            selectedTab
        }, set: { newTab in
            Task {
                if newTab == selectedTab {
                    /// Stupid hack to trigger onChange binding in tab views.
                    popToRootTab = .other
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        popToRootTab = selectedTab
                    }
                }
                
                selectedTab = newTab
            }
            
        })) {
            ForEach(availableTabs) { tab in
                Tab(tab.labelNew, systemImage: tab.iconName, value: tab) {
                    tab.makeContentView(popToRootTab: $popToRootTab)
                }
            }
        }
        .onAppear {
            availableTabs = Tabs.tabList()
        }
    }
}

#Preview {
    if #available(iOS 26.0, *) {
        TabbarView()
    } else {
        TabbarView18()
    }
}
