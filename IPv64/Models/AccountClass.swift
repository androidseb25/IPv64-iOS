//
//  AccountClass.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 22.10.25.
//
import Foundation

struct AccountClass: Codable {
    var dyndns_domain_limit, dyndns_update_limit, owndomain_limit, healthcheck_limit, healthcheck_update_limit, dyndns_ttl, api_limit, sms_limit, vpn_traffic, vpn_queue: Int
    var class_name: String
    
    enum CodingKeys: String, CodingKey {
        case class_name = "class_name"
        case dyndns_domain_limit = "dyndns_domain_limit"
        case dyndns_update_limit = "dyndns_update_limit"
        case owndomain_limit = "owndomain_limit"
        case healthcheck_limit = "healthcheck_limit"
        case healthcheck_update_limit = "healthcheck_update_limit"
        case dyndns_ttl = "dyndns_ttl"
        case api_limit = "api_limit"
        case sms_limit = "sms_limit"
        case vpn_traffic = "vpn_traffic"
        case vpn_queue = "vpn_queue"
    }
    
    static let empty = AccountClass(dyndns_domain_limit: 0, dyndns_update_limit: 0, owndomain_limit: 0, healthcheck_limit: 0, healthcheck_update_limit: 0, dyndns_ttl: 0, api_limit: 0, sms_limit: 0, vpn_traffic: 0, vpn_queue: 0, class_name: "")
}
