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
            WhatsNew(imageName: "ladybug", title: "Bug fixes".localized, subtitle: "Scanning the API key QR code when adding an account works again, and an invalid key now shows an error message after the scan.".localized),
        ]
    }
}

enum ActiveSheet: Identifiable {
    case whatsnew
    
    var id: Int {
        hashValue
    }
}
