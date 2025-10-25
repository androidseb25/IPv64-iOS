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

struct IPUpdateResult: Codable {
    var info: String = ""
    var ip: IPUpdate? = IPUpdate.empty
    var status: String = ""
    
    enum CodingKeys: String, CodingKey {
        case info = "info"
        case ip = "ip"
        case status = "status"
    }
    
    static var empty = IPUpdateResult(info: "", ip: IPUpdate.empty, status: "")
}

struct IPUpdate: Codable {
    var ipv4: String? = "0.0.0.0"
    var ipv6: String? = "::"
    
    enum CodingKeys: String, CodingKey {
        case ipv4 = "ipv4"
        case ipv6 = "ipv6"
    }
    
    static var empty = IPUpdate(ipv4: "0.0.0.0", ipv6: "::")
}
