//
//  Models.swift
//  IPv64
//
//  Created by Sebastian Rank on 06.11.22.
//

import Foundation
import SwiftUI

enum NetworkError: Error {
    case NoNetworkConnection
}

struct DomainResult : Codable {
    var subdomains: [String: Domain]?
    var info: String?
    var status: String?
    var add_domain: String?
    
    enum CodingKeys: String, CodingKey {
        case subdomains = "subdomains"
        case info = "info"
        case status = "status"
        case add_domain = "add_domain"
    }
}

struct AddDomainResult : Codable {
    var info: String?
    var status: String?
    var add_domain: String?
    
    enum CodingKeys: String, CodingKey {
        case info = "info"
        case status = "status"
        case add_domain = "add_domain"
    }
}

struct Domain : Codable {
    var updates: Int?
    var wildcard: Int?
    var domain_update_hash: String?
    var records: [RecordInfos]?
    
    enum CodingKeys: String, CodingKey {
        case updates = "updates"
        case wildcard = "wildcard"
        case domain_update_hash = "domain_update_hash"
        case records = "records"
    }
}

struct RecordInfos: Codable {
    var record_id: Int?
    var content: String?
    var ttl: Int?
    var type: String?
    var praefix: String?
    var last_update: String?
    
    enum CodingKeys: String, CodingKey {
        case record_id = "record_id"
        case content = "content"
        case ttl = "ttl"
        case type = "type"
        case praefix = "praefix"
        case last_update = "last_update"
    }
}

struct MyIP: Codable {
    var ip: String?
    
    enum CodingKeys: String, CodingKey {
        case ip = "ip"
    }
}

struct MyLogs: Codable {
    var id: UUID = UUID()
    var subdomain: String?
    var time: String?
    var header: String?
    var content: String?
    
    enum CodingKeys: String, CodingKey {
        case subdomain = "subdomain"
        case time = "time"
        case header = "header"
        case content = "content"
    }
}

struct Logs: Codable {
    var logs: [MyLogs]?
    
    enum CodingKeys: String, CodingKey {
        case logs = "logs"
    }
}

struct AccountInfo: Codable {
    var email: String? = ""
    var account_status: Int? = 0
    var reg_date: String? = "2022-01-01 00:00:00"
    var update_hash: String? = ""
    var api_key: String? = ""
    var dyndns_updates: Int? = 0
    var dyndns_subdomains: Int? = 0
    var owndomains: Int? = 0
    var healthchecks: Int? = 0
    var healthchecks_updates: Int? = 0
    var api_updates: Int? = 0
    var account_class: AccountClass? = AccountClass()
    var info: String? = ""
    var status: String? = ""
    var get_account_info: String? = ""
    
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
        case account_class = "account_class"
        case info = "info"
        case status = "status"
        case get_account_info = "get_account_info"
    }
}

struct AccountClass: Codable {
    var class_name: String? = ""
    var dyndns_domain_limit: Int? = 0
    var dyndns_update_limit: Int? = 0
    var owndomain_limit: Int? = 0
    var healthcheck_limit: Int? = 0
    var healthcheck_update_limit: Int? = 0
    var dyndns_ttl: Int? = 0
    var api_limit: Int? = 0
    
    enum CodingKeys: String, CodingKey {
        case class_name = "class_name"
        case dyndns_domain_limit = "dyndns_domain_limit"
        case dyndns_update_limit = "dyndns_update_limit"
        case owndomain_limit = "owndomain_limit"
        case healthcheck_limit = "healthcheck_limit"
        case healthcheck_update_limit = "healthcheck_update_limit"
        case dyndns_ttl = "dyndns_ttl"
        case api_limit = "api_limit"
    }
}

struct ErrorTyp: Codable {
    var icon: String?
    var iconColor: Color?
    var navigationTitle: String?
    var errorTitle: String?
    var errorDescription: String?
    var status: Int?
    
    enum CodingKeys: String, CodingKey {
        case icon = "icon"
        case navigationTitle = "navigationTitle"
        case errorTitle = "errorTitle"
        case errorDescription = "errorDescription"
        case status = "status"
    }
}

struct ErrorTypes {
    static var tooManyRequests: ErrorTyp {
        ErrorTyp(
            icon: "bolt.horizontal.icloud.fill;exclamationmark.arrow.triangle.2.circlepath",
            iconColor: .orange,
            navigationTitle: "Information",
            errorTitle: "Zu Viele Aktualisierungen!",
            errorDescription: "Du hast dein Limit von 5 API-Anfragen innerhalb der erlaubten 10 Sek. überschritten.",
            status: 429
        )
    }
    static var updateCoolDown: ErrorTyp {
        ErrorTyp(
            icon: "bolt.horizontal.icloud.fill;exclamationmark.arrow.triangle.2.circlepath",
            iconColor: .orange,
            navigationTitle: "Information",
            errorTitle: "Zu Viele Aktualisierungen!",
            errorDescription: "Die A-Record Aktualisierung kann nur alle 10 Sek. ausgeführt werden!",
            status: 429
        )
    }
    static var domainNotAvailable: ErrorTyp {
        ErrorTyp(
            icon: "xmark.icloud.fill",
            iconColor: .red,
            navigationTitle: "Fehler",
            errorTitle: "Domaine nicht verfügbar!",
            errorDescription: "Deine ausgewählte Domaine ist bereits vergeben!",
            status: 403
        )
    }
    static var domainCreatedSuccesfully: ErrorTyp {
        ErrorTyp(
            icon: "checkmark.icloud.fill",
            iconColor: .green,
            navigationTitle: "Erfolgreich",
            errorTitle: "Domaine wurde erfolgreich reserviert!",
            errorDescription: "Deine ausgewählte Domaine wurde erfolgreich, bei uns im System, für dich reserviert!",
            status: 201
        )
    }
    static var delete: ErrorTyp {
        ErrorTyp(
            icon: "trash.fill",
            iconColor: .red,
            navigationTitle: "Wirklick löschen?",
            errorTitle: "Willst du wirklich die Domain löschen?",
            errorDescription: "Deine Domaine wird mit allen bekannten DNS-Records unverzüglich gelöscht.",
            status: 202
        )
    }
    static var dnsRecordSuccesfullyCreated: ErrorTyp {
        ErrorTyp(
            icon: "checkmark.icloud.fill",
            iconColor: .green,
            navigationTitle: "Erfolgreich",
            errorTitle: "DNS-Record wurde erfolgreich erstellt!",
            errorDescription: "Dein DNS-Record wurde erfolgreich im System erstellt!",
            status: 201
        )
    }
    static var deleteDNSRecord: ErrorTyp {
        ErrorTyp(
            icon: "trash.fill",
            iconColor: .red,
            navigationTitle: "Wirklick löschen?",
            errorTitle: "Willst du wirklich den\nDNS-Record löschen?",
            errorDescription: "Dein DNS-Record wird mit sofortiger Wirkung aus deiner Domain gelöscht.",
            status: 202
        )
    }
    static var unauthorized: ErrorTyp {
        ErrorTyp(
            icon: "xmark.shield.fill",
            iconColor: .red,
            navigationTitle: "Fehlgeschlagen",
            errorTitle: "Authorisierung fehlgeschlagen!",
            errorDescription: "Deine Authorisierung am Server ist fehlgeschlagen, bitte melde dich erneut an.",
            status: 401
        )
    }
    static var websiteRequestError: ErrorTyp {
        ErrorTyp(
            icon: "bolt.horizontal.icloud.fill;exclamationmark.arrow.triangle.2.circlepath",
            iconColor: .red,
            navigationTitle: "Fehlgeschlagen",
            errorTitle: "Verbindung zum Server fehlgeschlagen!",
            errorDescription: "Es konnte keine Verbindung zum Server hergestellt werden!",
            status: 500
        )
    }
}

extension UIDevice {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}


enum ActiveSheet: Identifiable {
    case detail, add, adddns, help, error
    
    var id: Int {
        hashValue
    }
}

extension Bundle {
    
    var appName: String {
        return infoDictionary?["CFBundleName"] as! String
    }
    
    var bundleId: String {
        return bundleIdentifier!
    }
    
    var versionNumber: String {
        return infoDictionary?["CFBundleShortVersionString"] as! String
    }
    
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as! String
    }
    
}
