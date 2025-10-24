//
//  Tabs.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//


import Foundation
import SwiftUI

public enum Tabs: Int, Identifiable, Hashable, Decodable, Encodable {
    
    case domain, healthcheck, notification, settings, account, log, myip, about, other
    
    public var id: Int {
        rawValue
    }
    
    public var uuidString: String {
        UUID().uuidString
    }
    
    static func tabList() -> [Tabs] {
        return [.domain, .healthcheck, .notification, .settings]
    }
    
    @MainActor @ViewBuilder
    func makeContentView(popToRootTab: Binding<Tabs>) -> some View {
        switch self {
        case .domain:
            DomainView(popToRootTab: popToRootTab)
        case .healthcheck:
            HealthcheckView(popToRootTab: popToRootTab)
        case .notification:
            NotificationView(popToRootTab: popToRootTab)
        case .settings:
            SettingsView(popToRootTab: popToRootTab)
        case .account:
            AccountView(popToRootTab: popToRootTab)
        case .log:
            LogView(popToRootTab: popToRootTab)
        case .myip:
            MyIpView(popToRootTab: popToRootTab)
        case .about:
            AboutView(popToRootTab: popToRootTab)
        default:
            EmptyView()
        }
    }
    
    var labelNew: String {
        switch self {
        case .domain:
            return "Domain"
        case .healthcheck:
            return "Healthcheck"
        case .notification:
            return "Notification"
        case .settings:
            return "Settings"
        case .account:
            return "Account"
        case .log:
            return "Logs"
        case .myip:
            return "My IP"
        case .about:
            return "About"
        default:
            return ""
        }
    }
    
    var route: String {
        switch self {
        case .account:
            return "settings.account"
        case .log:
            return "settings.log"
        case .myip:
            return "settings.myip"
        case .about:
            return "settings.about"
        default:
            return ""
        }
    }
    
    @ViewBuilder
    var label: some View {
        switch self {
        case .domain:
            Label("Domain", systemImage: iconName)
        case .healthcheck:
            Label("Healthcheck", systemImage: iconName)
        case .notification:
            Label("Notification", systemImage: iconName)
        case .settings:
            Label("Settings", systemImage: iconName)
        default:
            EmptyView()
        }
    }
    
    var iconName: String {
        switch self {
        case .domain:
            return "network"
        case .healthcheck:
            return "bolt.heart"
        case .notification:
            return "bell.badge"
        case .settings:
            return "gearshape"
        case .account:
            return "person.circle"
        default:
            return "app.dashed"
        }
    }
}
