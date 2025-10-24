//
//  MyIP.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//

import Foundation

struct MyIP: Codable {
    var info: String? = ""
    var ip: String? = ""
    var status: String? = ""
    
    enum CodingKeys: String, CodingKey {
        case info = "info"
        case ip = "ip"
        case status = "status"
    }
    
    static var emptyV4 = MyIP(info: "", ip: "0.0.0.0", status: "")
    static var emptyV6 = MyIP(info: "", ip: "::", status: "")
}
