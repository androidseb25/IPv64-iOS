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
            WhatsNew(imageName: "chart.bar.xaxis", title: "Proxy64 chart".localized, subtitle: "Requests and traffic of your proxy hosts for the last 24 hours or 7 days, per node.".localized),
            WhatsNew(imageName: "cloud", title: "CDN64".localized, subtitle: "Usage now sits in the CDN64 screen, which also lists the domains you set up on the website without a Node64 (Mode 3).".localized),
            WhatsNew(imageName: "ellipsis.circle", title: "More".localized, subtitle: "Copy this app's API key, and edit channels with a swipe, including this device's channel.".localized),
        ]
    }
}

enum ActiveSheet: Identifiable {
    case whatsnew
    
    var id: Int {
        hashValue
    }
}
