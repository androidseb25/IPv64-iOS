//
//  AccountInfo.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 22.10.25.
//
import Foundation
import SwiftUI

struct AccountInfo : Codable {
    var account_status, dyndns_updates, dyndns_subdomains, owndomains, healthchecks, healthchecks_updates, api_updates, sms_count, vpn_limit_reached: Int
    var email, reg_date, update_hash, api_key, info, status, get_account_info: String
    var vpn_traffic_input, vpn_traffic_output: Int64
    
    var account_class: AccountClass
    
    enum CodingKeys: String, CodingKey {
        case email = "email"
        case account_status = "account_status"
        case reg_date = "reg_date"
        case update_hash = "update_hash"
        case api_key = "api_key"
        case dyndns_updates = "dyndns_updates"
        case dyndns_subdomains = "dyndns_subdomains"
        case owndomains = "owndomains"
        case healthchecks = "healthchecks"
        case healthchecks_updates = "healthchecks_updates"
        case api_updates = "api_updates"
        case sms_count = "sms_count"
        case account_class = "account_class"
        case vpn_traffic_input = "vpn_traffic_input"
        case vpn_traffic_output = "vpn_traffic_output"
        case vpn_limit_reached = "vpn_limit_reached"
        case info = "info"
        case status = "status"
        case get_account_info = "get_account_info"
    }
    
    static let empty = AccountInfo(account_status: 0, dyndns_updates: 0, dyndns_subdomains: 0, owndomains: 0, healthchecks: 0, healthchecks_updates: 0, api_updates: 0, sms_count: 0, vpn_limit_reached: 0, email: "test@test.de", reg_date: "0001-01-01T00:00:00", update_hash: "", api_key: "", info: "", status: "", get_account_info: "", vpn_traffic_input: 0, vpn_traffic_output: 0, account_class: AccountClass.empty)
    
    var AccountStatus: String {
        return account_status == 1 ? "active" : "disabled"
    }
    var AccountStatusColor: Color {
        return account_status == 1 ? .green : .red
    }
    
    var RegisteredSince: String {
        guard let date = DateFormatter.db.date(from: reg_date)
        else { return "01.01.0001" }
        
        return date.formatted(
            .dateTime
                .day(.twoDigits)
                .month(.twoDigits)
                .year(.defaultDigits)
                .locale(Locale(identifier: "de_DE"))
        )
    }
    
    var ApiUsageText: String {
        return usageText(used: api_updates, max: account_class.api_limit)
    }
    
    var ApiUsageColor: Color {
        return usageColor(used: api_updates, max: account_class.api_limit)
    }
    
    var DynDnsUpdateUsageText: String {
        return usageText(used: dyndns_updates, max: account_class.dyndns_update_limit)
    }
    
    var DynDnsUpdateUsageColor: Color {
        return usageColor(used: dyndns_updates, max: account_class.dyndns_update_limit)
    }
    
    var DynDnsDomainUsageText: String {
        return usageText(used: dyndns_subdomains, max: account_class.dyndns_domain_limit)
    }
    
    var DynDnsDomainUsageColor: Color {
        return usageColor(used: dyndns_subdomains, max: account_class.dyndns_domain_limit)
    }
    
    var OwnDomainsUsageText: String {
        return usageText(used: owndomains, max: account_class.owndomain_limit)
    }
    
    var OwnDomainsUsageColor: Color {
        return usageColor(used: owndomains, max: account_class.owndomain_limit)
    }
    
    var SmsUsageText: String {
        return usageText(used: sms_count, max: account_class.sms_limit)
    }
    
    var SmsUsageColor: Color {
        return usageColor(used: sms_count, max: account_class.sms_limit)
    }
    
    var HealthcheckUsageText: String {
        return usageText(used: healthchecks, max: account_class.healthcheck_limit)
    }
    
    var HealthcheckUsageColor: Color {
        return usageColor(used: healthchecks, max: account_class.healthcheck_limit)
    }
    
    var HealthcheckUpdateUsageText: String {
        return usageText(used: healthchecks_updates, max: account_class.healthcheck_update_limit)
    }
    
    var HealthcheckUpdateUsageColor: Color {
        return usageColor(used: healthchecks_updates, max: account_class.healthcheck_update_limit)
    }
    
}
