//
//  Tabs.swift
//  IPv64
//
//  Created by Sebastian Rank on 08.08.23.
//

import SwiftUI

enum Tab: Int, Identifiable, Hashable {
    case domains, healthchecks, integrations, profile, blocklist, other
    
    var id: Int {
        rawValue
    }
    
    static func tabList() -> [Tab] {
        //    if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac {
        //      return [.timeline, .trending, .federated, .local, .notifications, .mentions, .explore, .messages, .settings]
        //    } else {
        //      return [.timeline, .notifications, .explore, .messages, .profile]
        //    }
        return [.domains, .healthchecks, .integrations, .blocklist, .profile]
    }
    
    @ViewBuilder
    func makeContentView(popToRootTab: Binding<Tab>) -> some View {
        switch self {
        case .domains:
            ContentView(popToRootTab: popToRootTab)
        case .healthchecks:
            HealthcheckView(popToRootTab: popToRootTab)
        case .integrations:
            IntegrationView(popToRootTab: popToRootTab)
        case .profile:
            ProfilView(popToRootTab: popToRootTab)
        case .blocklist:
            BlocklistView(popToRootTab: popToRootTab)
        case .other:
            EmptyView()
        }
    }
    
    @ViewBuilder
    var label: some View {
        switch self {
        case .domains:
            Label(labelName, systemImage: iconName)
        case .healthchecks:
            Label(labelName, systemImage: iconName)
        case .integrations:
            Label(labelName, systemImage: iconName)
        case .profile:
            Label(labelName, systemImage: iconName)
        case .blocklist:
            Label(labelName, systemImage: iconName)
        case .other:
            EmptyView()
        }
    }
    
    var iconName: String {
        switch self {
        case .domains:
            return "network"
        case .healthchecks:
            return "bolt.heart"
        case .integrations:
            return "bell.and.waveform"
        case .profile:
            return "person.circle"
        case .blocklist:
            return "shield.lefthalf.filled"
        case .other:
            return ""
        }
    }
    
    var labelName: String {
        switch self {
        case .domains:
            return "Domains"
        case .healthchecks:
            return "Health"
        case .integrations:
            return "Mitteilungen"
        case .profile:
            return "Account"
        case .blocklist:
            return "Blocklist"
        case .other:
            return ""
        }
    }
}
