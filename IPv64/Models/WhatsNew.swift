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
            WhatsNew(imageName: "appletv", title: String(localized: "Apple TV app"), subtitle: String(localized: "Your DNS64 dashboard and query log on the big screen. Nodes you connect here appear on the Apple TV via iCloud.")),
            WhatsNew(imageName: "character.bubble", title: String(localized: "German"), subtitle: String(localized: "The app is now also available in German.")),
            WhatsNew(imageName: "chart.bar.xaxis", title: String(localized: "Proxy64 chart"), subtitle: String(localized: "Requests and traffic of your proxy hosts for the last 24 hours or 7 days, per node.")),
            WhatsNew(imageName: "cloud", title: String(localized: "CDN64"), subtitle: String(localized: "Usage now sits in the CDN64 screen, which also lists the domains you set up on the website without a Node64 (Mode 3).")),
            WhatsNew(imageName: "ellipsis.circle", title: String(localized: "More"), subtitle: String(localized: "Copy this app's API key, and edit channels with a swipe, including this device's channel.")),
            WhatsNew(imageName: "ladybug", title: String(localized: "Bug fixes"), subtitle: String(localized: "The DynDNS IP check no longer counts CDN and failover records, so CDN domains no longer show a different IP.")),
        ]
    }
}

enum ActiveSheet: Identifiable {
    case whatsnew
    
    var id: Int {
        hashValue
    }
}
