//
//  WhatsNew.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 13.02.26.
//

import Foundation
import Combine

struct WhatsNew : Codable {
    var id = UUID()
    var imageName: String
    var title: String
    var subtitle: String
    var assetIcon: Bool
    
    enum CodingKeys: String, CodingKey {
        case imageName = "imageName"
        case title = "title"
        case subtitle = "subtitle"
        case assetIcon = "assetIcon"
    }
    
    init(imageName: String = "", title: String = "", subtitle: String = "", assetIcon: Bool = false) {
        self.imageName = imageName
        self.title = title
        self.subtitle = subtitle
        self.assetIcon = assetIcon
    }
}

extension WhatsNew {
    /// Entries of the current version (shared by WhatsNewView and WhatsNewView26).
    static var current: [WhatsNew] {
        [
            WhatsNew(imageName: "bolt.heart", title: "Healthchecks 2.0".localized, subtitle: "Checks from several locations with status, statistics, incidents and events in collapsible sections. Create and edit them right in the app.".localized),
            WhatsNew(imageName: "point.3.connected.trianglepath.dotted", title: "Nodes".localized, subtitle: "Link your Node64 or connect directly in your network: live status, modules, logs and commands. Direct connections show the installed node version.".localized),
            WhatsNew(imageName: "arrow.left.arrow.right", title: "Proxy64 & CDN64".localized, subtitle: "Manage the proxy hosts of your node and make them reachable from the internet with CDN64.".localized),
            WhatsNew(imageName: "server.rack", title: "DNS64".localized, subtitle: "Ad and tracker blocking on your node: pause it, see statistics, local DNS records and the live query log, where you can block or allow any domain.".localized),
            WhatsNew(imageName: "chart.xyaxis.line", title: "Monitor64".localized, subtitle: "The hosts your node monitors, with charts for the host and its services, and open problems, now in Healthchecks.".localized),
            WhatsNew(imageName: "bell.badge", title: "Push notifications".localized, subtitle: "Encrypted push notifications via SecNtfy with delivery receipts, and notification channels instead of integrations. This device's channel is marked and can't be deleted by mistake.".localized),
            WhatsNew(imageName: "eye.slash", title: "Screenshot protection".localized, subtitle: "Screenshots and screen recordings show the app black. You can turn it off under More → App.".localized),
            WhatsNew(imageName: "square.grid.2x2", title: "Widgets & Control Center".localized, subtitle: "The Healthchecks widget in every size, a DNS64 widget with chart and pause, and a DNS64 switch in Control Center.".localized),
            WhatsNew(imageName: "ellipsis.circle", title: "More".localized, subtitle: "API keys, account links, IP lookup, password check, the honeypot network with daily bar charts and system logs for troubleshooting.".localized),
        ]
    }
}

enum ActiveSheet: Identifiable {
    case whatsnew
    
    var id: Int {
        hashValue
    }
}
