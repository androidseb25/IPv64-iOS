//
//  Tabs.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//


import Foundation
import SwiftUI

public enum Tabs: Int, Identifiable, Hashable, Decodable, Encodable {
    
    // New cases go last: the raw value is persisted in CURRENT_TAB.
    case domain, healthcheck, notification, settings, account, log, myip, about, syslog, other, cdn, proxy64, dns64
    
    public var id: Int {
        rawValue
    }
    
    public var uuidString: String {
        UUID().uuidString
    }
    
    /// Tab bar as in Android 2.1.0 (`Tabs.tabList`): Proxy64 replaces CDN64 and DNS64 appears only while a
    /// connected node has that module active. `.settings` is the More tab.
    static func tabList(proxyActive: Bool, dnsActive: Bool) -> [Tabs] {
        var list: [Tabs] = [.domain, .healthcheck, proxyActive ? .proxy64 : .cdn]
        if dnsActive { list.append(.dns64) }
        return list + [.settings]
    }
    
    @MainActor @ViewBuilder
    func makeContentView(popToRootTab: Binding<Tabs>) -> some View {
        switch self {
        case .domain:
            DomainView(popToRootTab: popToRootTab)
        case .healthcheck:
            HealthcheckView(popToRootTab: popToRootTab)
        case .notification:
            ChannelsView()
        case .settings:
            SettingsView(popToRootTab: popToRootTab)
        case .account:
            AccountView(popToRootTab: popToRootTab)
        case .log:
            LogView(popToRootTab: popToRootTab)
        case .syslog:
            LoggerView(popToRootTab: popToRootTab, showToolbar: false)
        case .myip:
            ThreatLookupView()
        case .about:
            AboutView(popToRootTab: popToRootTab)
        case .cdn:
            CdnView(popToRootTab: popToRootTab)
        case .proxy64:
            ProxyView(popToRootTab: popToRootTab)
        case .dns64:
            NodeDnsView(popToRootTab: popToRootTab)
        default:
            EmptyView()
        }
    }
    
    var labelNew: String {
        switch self {
        case .domain:
            return "DynDNS"
        case .healthcheck:
            return String(localized: "Healthchecks")
        case .notification:
            return String(localized: "Channels")
        case .settings:
            return String(localized: "More")
        case .cdn:
            return "CDN64"
        case .proxy64:
            return "Proxy64"
        case .dns64:
            return "DNS64"
        case .account:
            return String(localized: "Account")
        case .log:
            return String(localized: "Logs")
        case .syslog:
            return String(localized: "System Logs")
        case .myip:
            return String(localized: "IP lookup & My IP")
        case .about:
            return String(localized: "About")
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
        case .notification:
            return "settings.notification"
        case .syslog:
            return "settings.syslog"
        default:
            return ""
        }
    }
    
    @ViewBuilder
    var label: some View {
        switch self {
        case .domain:
            Label("DynDNS", systemImage: iconName)
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
            return "ellipsis"
        case .cdn:
            return "cloud"
        case .proxy64:
            return "arrow.left.arrow.right"
        case .dns64:
            return "server.rack"
        case .account:
            return "person.circle"
        default:
            return "app.dashed"
        }
    }
}
