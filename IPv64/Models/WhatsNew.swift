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

enum ActiveSheet: Identifiable {
    case whatsnew
    
    var id: Int {
        hashValue
    }
}
