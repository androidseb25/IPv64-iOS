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

struct DomainItems : Codable {
    var id = UUID()
    var name: String?
    var list: [Domain]?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case list = "list"
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
    var id = UUID()
    var name: String = ""
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
    var expandLog: Bool = false
    
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
    var sms_count: Int? = 0
    var account_class: AccountClass? = AccountClass()
    var devicetoken: String? = ""
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
        case sms_count = "sms_count"
        case account_class = "account_class"
        case devicetoken = "devicetoken"
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
    var sms_limit: Int? = 0
    
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
    }
}

struct Account: Codable {
    var ApiKey: String?
    var AccountName: String?
    var DeviceToken: String?
    var Since: String?
    var Active: Bool?
    
    enum CodingKeys: String, CodingKey {
        case ApiKey = "ApiKey"
        case AccountName = "AccountName"
        case DeviceToken = "DeviceToken"
        case Since = "Since"
        case Active = "Active"
    }
}

struct HealthCheckResult: Codable {
    
    var domain: [HealthCheck] = []
    var info: String?
    var status: String?
    var get_account_info: String?
    
    // Define DynamicCodingKeys type needed for creating
    // decoding container from JSONDecoder
    private struct DynamicCodingKeys: CodingKey {
        // Use for string-keyed dictionary
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        // Use for integer-keyed dictionary
        var intValue: Int?
        init?(intValue: Int) {
            // We are not using this, thus just return nil
            return nil
        }
        
    }
    
    init(from decoder: Decoder) throws {
        
        // 1
        // Create a decoding container using DynamicCodingKeys
        // The container will contain all the JSON first level key
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        var tempArray = [HealthCheck]()
        
        // 2
        // Loop through each key (healthcheck Domain) in container
        for key in container.allKeys {
            // Decode healthchecks using key & keep decoded healthcheck object in tempArray
            if (key.stringValue == "info") {
                info = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            } else if (key.stringValue == "status") {
                status = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            } else if (key.stringValue == "get_account_info") {
                get_account_info = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            } else {
                let decodedObject = try container.decode(HealthCheck.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
                tempArray.append(decodedObject)
            }
        }
        
        // 3
        // Finish decoding all HealthCheck objects. Thus assign tempArray to array.
        domain = tempArray
    }
    
    init(domain: [HealthCheck] = [], info: String = "", status: String = "", get_account_info: String = "") {
        self.domain = domain
        self.info = info
        self.status = status
        self.get_account_info = get_account_info
    }
}

struct HealthCheck: Codable {
    // healthstatus == 1 = Active; 2 = Paused; 3 = Warning; 4 = Alarm;
    var name: String = ""
    var healthstatus: Int = 0
    var healthtoken: String = ""
    var add_time: String? = ""
    var last_update_time: String? = ""
    var alarm_time: String? = ""
    var alarm_down: Int = 0
    var alarm_up: Int = 0
    var integration_id: String = "0"
    var alarm_count: Int = 0
    var alarm_unit: Int = 0
    var grace_count: Int = 0
    var grace_unit: Int = 0
    var pings_total: Int = 0
    var type: String = ""
    var events: [HealthEvents] = []
    
    // 1
    // Define healthcheck Domain
    var keyInd: String = ""
    
    // 2
    // Define coding key for decoding use
    enum CodingKeys: String, CodingKey {
        case name = "name"
        case healthstatus = "healthstatus"
        case healthtoken = "healthtoken"
        case add_time = "add_time"
        case last_update_time = "last_update_time"
        case alarm_time = "alarm_time"
        case alarm_down = "alarm_down"
        case alarm_up = "alarm_up"
        case integration_id = "integration_id"
        case alarm_count = "alarm_count"
        case alarm_unit = "alarm_unit"
        case grace_count = "grace_count"
        case grace_unit = "grace_unit"
        case pings_total = "pings_total"
        case type = "type"
        case keyInd = "keyInd"
        case events = "events"
    }
    
    init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 3
        // Decode
        name = try container.decode(String.self, forKey: CodingKeys.name)
        healthstatus = try container.decode(Int.self, forKey: CodingKeys.healthstatus)
        healthtoken = try container.decode(String.self, forKey: CodingKeys.healthtoken)
        add_time = try container.decode(String.self, forKey: CodingKeys.add_time)
        last_update_time = try container.decode(String.self, forKey: CodingKeys.last_update_time)
        alarm_time = try container.decode(String.self, forKey: CodingKeys.alarm_time)
        alarm_down = try container.decode(Int.self, forKey: CodingKeys.alarm_down)
        alarm_up = try container.decode(Int.self, forKey: CodingKeys.alarm_up)
        integration_id = try container.decode(String.self, forKey: CodingKeys.integration_id)
        alarm_count = try container.decode(Int.self, forKey: CodingKeys.alarm_count)
        alarm_unit = try container.decode(Int.self, forKey: CodingKeys.alarm_unit)
        grace_count = try container.decode(Int.self, forKey: CodingKeys.grace_count)
        grace_unit = try container.decode(Int.self, forKey: CodingKeys.grace_unit)
        pings_total = try container.decode(Int.self, forKey: CodingKeys.pings_total)
        type = try container.decode(String.self, forKey: CodingKeys.type)
        events = try container.decode([HealthEvents].self, forKey: CodingKeys.events)
        
        // 4
        // Extract healthcheckDomain from coding path
        if (container.codingPath.first!.stringValue != nil) {
            keyInd = container.codingPath.first!.stringValue
        }
    }
    
    init(name: String = "", healthstatus: Int = 0, healthtoken: String = "", add_time: String? = "", last_update_time: String? = "", alarm_time: String? = "", alarm_down: Int = 0, alarm_up: Int = 0, integration_id: String = "0", alarm_count: Int = 0, alarm_unit: Int = 0, grace_count: Int = 0, grace_unit: Int = 0, pings_total: Int = 0, type: String = "", events: [HealthEvents] = []) {
        self.name = name
        self.healthstatus = healthstatus
        self.healthtoken = healthtoken
        self.add_time = add_time
        self.last_update_time = last_update_time
        self.alarm_time = alarm_time
        self.alarm_down = alarm_down
        self.alarm_up = alarm_up
        self.integration_id = integration_id
        self.alarm_count = alarm_count
        self.alarm_unit = alarm_unit
        self.grace_count = grace_count
        self.grace_unit = grace_unit
        self.pings_total = pings_total
        self.type = type
        self.events = events
    }
}

struct HealthEvents: Codable {
    var event_time: String?
    var status: Int?
    var text: String?
    
    enum CodingKeys: String, CodingKey {
        case event_time = "event_time"
        case status = "status"
        case text = "text"
    }
}

struct StatusTyp {
    var statusId: Int?
    var name: String?
    var icon: String?
    var color: Color?
    
    enum CodingKeys: String, CodingKey {
        case statusId = "statusId"
        case name = "name"
        case icon = "icon"
        case color = "color"
    }
}

struct IntegrationResult: Codable {
    
    var integration: [Integration] = []
    var service: String?
    var info: String?
    var status: String?
    var get_account_info: String?
    
    // Define DynamicCodingKeys type needed for creating
    // decoding container from JSONDecoder
    private struct DynamicCodingKeys: CodingKey {
        // Use for string-keyed dictionary
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        // Use for integer-keyed dictionary
        var intValue: Int?
        init?(intValue: Int) {
            // We are not using this, thus just return nil
            return nil
        }
        
    }
    
    init(from decoder: Decoder) throws {
        
        // 1
        // Create a decoding container using DynamicCodingKeys
        // The container will contain all the JSON first level key
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        var tempArray = [Integration]()
        
        // 2
        // Loop through each key (healthcheck Domain) in container
        for key in container.allKeys {
            // Decode healthchecks using key & keep decoded healthcheck object in tempArray
            if (key.stringValue == "info") {
                info = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            } else if (key.stringValue == "status") {
                status = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            } else if (key.stringValue == "get_account_info") {
                get_account_info = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            } else {
                let decodedObject = try container.decode(Integration.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
                tempArray.append(decodedObject)
            }
        }
        
        // 3
        // Finish decoding all HealthCheck objects. Thus assign tempArray to array.
        integration = tempArray
    }
    
    init(integration: [Integration] = [], info: String = "", status: String = "", get_account_info: String = "") {
        self.integration = integration
        self.info = info
        self.status = status
        self.get_account_info = get_account_info
    }
}

struct Integration: Codable, Hashable {
    var i_uuid = UUID()
    var integration: String?
    var integration_id: Int = 0
    var integration_name: String?
    var add_time: String?
    var last_used: String?
    
    enum CodingKeys: String, CodingKey {
        case integration = "integration"
        case integration_id = "integration_id"
        case integration_name = "integration_name"
        case add_time = "add_time"
        case last_used = "last_used"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            // 3
            // Decode
            integration = try container.decode(String.self, forKey: CodingKeys.integration)
            integration_id = try container.decode(Int.self, forKey: CodingKeys.integration_id)
            integration_name = try container.decode(String.self, forKey: CodingKeys.integration_name)
            add_time = try container.decode(String.self, forKey: CodingKeys.add_time)
            last_used = try container.decode(String.self, forKey: CodingKeys.last_used)
            
            // 4
            // Extract healthcheckDomain from coding path
            //keyInd = container.codingPath.first!.stringValue
        } catch {
            print(error)
        }
    }
}

struct HealthcheckStatisticsResult: Codable {
    var info: String = ""
    var status: String = ""
    var get_account_info: String = ""
    var statistics: [String: [HealthcheckStatistics]]?
    
    enum CodingKeys: String, CodingKey {
        case info = "info"
        case status = "status"
        case get_account_info = "get_account_info"
        case statistics = "statistics"
    }
}

struct HealthcheckStatistics: Codable {
    var id = UUID()
    var time: String = ""
    var measurement: String = ""
    var latency: Double = 0.0
    
    enum CodingKeys: String, CodingKey {
        case time = "time"
        case measurement = "measurement"
        case latency = "latency"
    }
}

struct BlockerNode : Codable {
    var blocker_id: String?
    var name: String?
    var last_contact: String?
    var reported_ips_count: Int?
    var blocked_with_help: Int?
    var status: Int?
    
    enum CodingKeys: String, CodingKey {
        case blocker_id = "blocker_id"
        case name = "name"
        case last_contact = "last_contact"
        case reported_ips_count = "reported_ips_count"
        case blocked_with_help = "blocked_with_help"
        case status = "status"
    }
}

struct BlockerNodeResults : Codable {
    var blockers: [BlockerNode] = []
    var info: String?
    var status: String?
    var get_blocker: String?
    
    enum CodingKeys: String, CodingKey {
        case blockers = "blockers"
        case info = "info"
        case status = "status"
        case get_blocker = "get_blocker"
    }
    
    static var empty: BlockerNodeResults { return BlockerNodeResults(blockers: [], info: "", status: "", get_blocker: "") }
}

struct PoisonedIP : Codable {
    var blocker_id: String
    var report_ip: String
    var port: String?
    var category: String?
    var info: String?
    
    enum CodingKeys: String, CodingKey {
        case blocker_id = "blocker_id"
        case report_ip = "report_ip"
        case port = "port"
        case category = "category"
        case info = "info"
    }
    
    static var empty: PoisonedIP { return PoisonedIP(blocker_id: "", report_ip: "", port: "", category: "", info: "") }
}

struct PoisonedIPResult : Codable {
    var info: String?
    var status: String?
    var report_ip: String?
    
    enum CodingKeys: String, CodingKey {
        case info = "info"
        case status = "status"
        case report_ip = "report_ip"
    }
}

struct AlarmUnit: Codable {
    var id: Int?
    var text: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case text = "text"
    }
}

struct AlarmUnitTypes {
    static var minutes: AlarmUnit {
        AlarmUnit(id: 1, text: "Minuten")
    }
    static var stunden: AlarmUnit {
        AlarmUnit(id: 2, text: "Stunden")
    }
    static var tage: AlarmUnit {
        AlarmUnit(id: 3, text: "Tage")
    }
}

struct StatusTypes {
    static var active: StatusTyp {
        StatusTyp(statusId: 1, name: "Aktiv", icon: "checkmark.circle", color: .green)
    }
    static var pause: StatusTyp {
        StatusTyp(statusId: 2, name: "Pause", icon: "pause.circle", color: .teal)
    }
    static var warning: StatusTyp {
        StatusTyp(statusId: 3, name: "Warnung", icon: "exclamationmark.triangle.fill", color: .orange)
    }
    static var alarm: StatusTyp {
        StatusTyp(statusId: 4, name: "Alarm", icon: "light.beacon.max.fill", color: .red)
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
    
    static var poisonedIpSuccesfully: ErrorTyp {
        ErrorTyp(
            icon: "checkmark.icloud.fill",
            iconColor: .green,
            navigationTitle: "Erfolgreich",
            errorTitle: "Bösartige IP wurde erfolgreich gemeldet!",
            errorDescription: "Deine Bösartige IP wurde erfolgreich, bei uns im System gemeldet!",
            status: 201
        )
    }
    
    static var poisonedIpError: ErrorTyp {
        ErrorTyp(
            icon: "xmark.icloud.fill",
            iconColor: .red,
            navigationTitle: "Fehler",
            errorTitle: "Fehlerhafte IP!",
            errorDescription: "Deine übergebene bösartige IP ist nicht korrekt!",
            status: 403
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
    
    static var deletehealth: ErrorTyp {
        ErrorTyp(
            icon: "trash.fill",
            iconColor: .red,
            navigationTitle: "Wirklick löschen?",
            errorTitle: "Willst du wirklich den Healthcheck löschen?",
            errorDescription: "Dein Healthcheck wird mit allen dazugehörigen Events unverzüglich gelöscht.",
            status: 202
        )
    }
    
    static var deleteIntegration: ErrorTyp {
        ErrorTyp(
            icon: "trash.fill",
            iconColor: .red,
            navigationTitle: "Wirklick löschen?",
            errorTitle: "Willst du wirklich die Integration löschen?",
            errorDescription: "Deine Integration wird aus allen Healthchecks gelöscht.",
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
    
    static var healthcheckCreatedSuccesfully: ErrorTyp {
        ErrorTyp(
            icon: "waveform.path.ecg",
            iconColor: .green,
            navigationTitle: "Erfolgreich",
            errorTitle: "Healthcheck wurde erfolgreich erstellt!",
            errorDescription: "Dein neuer Healthcheck ist nun online!",
            status: 201
        )
    }
    
    static var healthcheckUpdatedSuccesfully: ErrorTyp {
        ErrorTyp(
            icon: "waveform.path.ecg",
            iconColor: .green,
            navigationTitle: "Erfolgreich",
            errorTitle: "Healthcheck erfolgreich aktualisiert!",
            errorDescription: "Dein Healthcheck wurde erfolgreich aktualisiert!",
            status: 201
        )
    }
    
    static var accountSuccessfullyAdded: ErrorTyp {
        ErrorTyp(
            icon: "person.crop.circle.badge.checkmark",
            iconColor: .green,
            navigationTitle: "Erfolgreich",
            errorTitle: "Account erfolgreich hinzugefügt!",
            errorDescription: "",
            status: 201
        )
    }
    
    static var accountFound: ErrorTyp {
        ErrorTyp(
            icon: "person.crop.circle.badge.exclamationmark",
            iconColor: .orange,
            navigationTitle: "Achtung",
            errorTitle: "Account wurde bereits hinzugefügt!",
            errorDescription: "Dein API-Key ist bereits mit einem Account in der App verknüpft.",
            status: 201
        )
    }
    
    static var accountNotFound: ErrorTyp {
        ErrorTyp(
            icon: "person.crop.circle.badge.questionmark",
            iconColor: .red,
            navigationTitle: "Fehler!",
            errorTitle: "API-Key nicht gefunden!",
            errorDescription: "Bist du dir sicher das der API-Key korrekt geschrieben ist?",
            status: 401
        )
    }
    
    static var deleteAccount: ErrorTyp {
        ErrorTyp(
            icon: "trash.fill",
            iconColor: .red,
            navigationTitle: "Wirklick löschen?",
            errorTitle: "Willst du wirklich den\nAccount löschen?",
            errorDescription: "Dein Account wird mit sofortiger Wirkung aus der App gelöscht.",
            status: 202
        )
    }
}

public var dynDomainList = [
    "ipv64.net",
    "ipv64.de",
    "any64.de",
    "eth64.de",
    "home64.de",
    "iot64.de",
    "lan64.de",
    "nas64.de",
    "srv64.de",
    "tcp64.de",
    "udp64.de",
    "vpn64.de",
    "wan64.de"
]

public var badNodeCategory: [BadNodeCategory] = [
    BadNodeCategory(id: 1, text: "SSH"),
    BadNodeCategory(id: 2, text: "HTTP/S"),
    BadNodeCategory(id: 3, text: "Mail"),
    BadNodeCategory(id: 4, text: "FTP"),
    BadNodeCategory(id: 5, text: "ICMP"),
    BadNodeCategory(id: 6, text: "DoS"),
    BadNodeCategory(id: 7, text: "DDoS"),
    BadNodeCategory(id: 8, text: "Flooding"),
    BadNodeCategory(id: 9, text: "Web"),
    BadNodeCategory(id: 10, text: "Malware"),
    BadNodeCategory(id: 11, text: "Bots"),
    BadNodeCategory(id: 12, text: "TCP"),
    BadNodeCategory(id: 13, text: "UDP"),
]

public struct BadNodeCategory: Codable {
    var id: Int?
    var text: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case text = "text"
    }
}

struct WhatsNewObj : Codable {
    var id = UUID()
    var imageName: String
    var title: String
    var subtitle: String
    
    enum CodingKeys: String, CodingKey {
        case imageName = "imageName"
        case title = "title"
        case subtitle = "subtitle"
    }
    
    init(imageName: String = "", title: String = "", subtitle: String = "") {
        self.imageName = imageName
        self.title = title
        self.subtitle = subtitle
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
    case detail, add, adddns, help, error, qrcode, whatsnew, edit, integrationselection
    
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

struct MyNavigation<Content>: View where Content: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack(root: content)
        } else {
            NavigationView(content: content)
        }
    }
}

struct DummyData {
    static var Healthcheck = HealthCheck(
        name: "Healthcheck Test",
        healthstatus: 3,
        healthtoken: "123456789abcdefghijklmnop",
        add_time: "2023-01-01 00:00:00",
        last_update_time: "2023-01-01 00:00:00",
        alarm_time: "2023-01-01 00:00:00",
        alarm_down: 0,
        alarm_up: 0,
        integration_id: "0",
        alarm_count: 1,
        alarm_unit: 1,
        grace_count: 1,
        grace_unit: 1,
        pings_total: 1,
        events: [
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 1,
                text: "123456789"
            ),
            HealthEvents(
                event_time: "2023-01-01 01:00:00",
                status: 4,
                text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 3,
                text: "123456789"
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 0,
                text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"
            ),
            HealthEvents(
                event_time: "2023-01-01 00:00:00",
                status: 1,
                text: Optional("Healthcheck Einstellungen übernommen.")
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 4,
                text: "123456789"
            ),
            HealthEvents(
                event_time: "2023-01-01 01:00:00",
                status: 3,
                text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 0,
                text: "123456789"
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 1,
                text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"
            ),
            HealthEvents(
                event_time: "2023-01-01 00:00:00",
                status: 4,
                text: Optional("Healthcheck Einstellungen übernommen.")
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 3,
                text: "123456789"
            )
        ]
    )
    
    static func HealthcheckListCustom(customCount: Int) -> [HealthCheck] {
        var list: [HealthCheck] = []
        for i in 0..<customCount {
            var hc = self.Healthcheck
            hc.name = "Healthcheck \(i+1)"
            hc.healthtoken = "123456789abcdefghijklmnop\(i+1)"
            list.append(hc)
        }
        return list
    }
    
}

struct Functions {
    static func getOrientationWidth() -> CGFloat {
        
        if !UIDevice.isIPad {
            return .infinity
        }
        
        if UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight {
            return UIScreen.main.bounds.width / 2.3
        } else {
            return UIScreen.main.bounds.width / 1
        }
    }
}

// Our custom view modifier to track rotation and
// call our action
struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

// A View wrapper to make the modifier easier to use
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}

public enum Model : String {
    
    //Simulator
    case simulator     = "simulator/sandbox",
         
         //iPod
         iPod1              = "iPod 1",
         iPod2              = "iPod 2",
         iPod3              = "iPod 3",
         iPod4              = "iPod 4",
         iPod5              = "iPod 5",
         iPod6              = "iPod 6",
         iPod7              = "iPod 7",
         
         //iPad
         iPad2              = "iPad 2",
         iPad3              = "iPad 3",
         iPad4              = "iPad 4",
         iPadAir            = "iPad Air ",
         iPadAir2           = "iPad Air 2",
         iPadAir3           = "iPad Air 3",
         iPadAir4           = "iPad Air 4",
         iPadAir5           = "iPad Air 5",
         iPad5              = "iPad 5", //iPad 2017
         iPad6              = "iPad 6", //iPad 2018
         iPad7              = "iPad 7", //iPad 2019
         iPad8              = "iPad 8", //iPad 2020
         iPad9              = "iPad 9", //iPad 2021
         iPad10             = "iPad 10", //iPad 2022
         
         //iPad Mini
         iPadMini           = "iPad Mini",
         iPadMini2          = "iPad Mini 2",
         iPadMini3          = "iPad Mini 3",
         iPadMini4          = "iPad Mini 4",
         iPadMini5          = "iPad Mini 5",
         iPadMini6          = "iPad Mini 6",
         
         //iPad Pro
         iPadPro9_7         = "iPad Pro 9.7\"",
         iPadPro10_5        = "iPad Pro 10.5\"",
         iPadPro11          = "iPad Pro 11\"",
         iPadPro2_11        = "iPad Pro 11\" 2nd gen",
         iPadPro3_11        = "iPad Pro 11\" 3rd gen",
         iPadPro12_9        = "iPad Pro 12.9\"",
         iPadPro2_12_9      = "iPad Pro 2 12.9\"",
         iPadPro3_12_9      = "iPad Pro 3 12.9\"",
         iPadPro4_12_9      = "iPad Pro 4 12.9\"",
         iPadPro5_12_9      = "iPad Pro 5 12.9\"",
         
         //iPhone
         iPhone4            = "iPhone 4",
         iPhone4S           = "iPhone 4S",
         iPhone5            = "iPhone 5",
         iPhone5S           = "iPhone 5S",
         iPhone5C           = "iPhone 5C",
         iPhone6            = "iPhone 6",
         iPhone6Plus        = "iPhone 6 Plus",
         iPhone6S           = "iPhone 6S",
         iPhone6SPlus       = "iPhone 6S Plus",
         iPhoneSE           = "iPhone SE",
         iPhone7            = "iPhone 7",
         iPhone7Plus        = "iPhone 7 Plus",
         iPhone8            = "iPhone 8",
         iPhone8Plus        = "iPhone 8 Plus",
         iPhoneX            = "iPhone X",
         iPhoneXS           = "iPhone XS",
         iPhoneXSMax        = "iPhone XS Max",
         iPhoneXR           = "iPhone XR",
         iPhone11           = "iPhone 11",
         iPhone11Pro        = "iPhone 11 Pro",
         iPhone11ProMax     = "iPhone 11 Pro Max",
         iPhoneSE2          = "iPhone SE 2nd gen",
         iPhone12Mini       = "iPhone 12 Mini",
         iPhone12           = "iPhone 12",
         iPhone12Pro        = "iPhone 12 Pro",
         iPhone12ProMax     = "iPhone 12 Pro Max",
         iPhone13Mini       = "iPhone 13 Mini",
         iPhone13           = "iPhone 13",
         iPhone13Pro        = "iPhone 13 Pro",
         iPhone13ProMax     = "iPhone 13 Pro Max",
         iPhoneSE3          = "iPhone SE 3nd gen",
         iPhone14           = "iPhone 14",
         iPhone14Plus       = "iPhone 14 Plus",
         iPhone14Pro        = "iPhone 14 Pro",
         iPhone14ProMax     = "iPhone 14 Pro Max",
         iPhone15           = "iPhone 15",
         iPhone15Plus       = "iPhone 15 Plus",
         iPhone15Pro        = "iPhone 15 Pro",
         iPhone15ProMax     = "iPhone 15 Pro Max",
         
         // Apple Watch
         AppleWatch1         = "Apple Watch 1gen",
         AppleWatchS1        = "Apple Watch Series 1",
         AppleWatchS2        = "Apple Watch Series 2",
         AppleWatchS3        = "Apple Watch Series 3",
         AppleWatchS4        = "Apple Watch Series 4",
         AppleWatchS5        = "Apple Watch Series 5",
         AppleWatchSE        = "Apple Watch Special Edition",
         AppleWatchS6        = "Apple Watch Series 6",
         AppleWatchS7        = "Apple Watch Series 7",
         
         //Apple TV
         AppleTV1           = "Apple TV 1gen",
         AppleTV2           = "Apple TV 2gen",
         AppleTV3           = "Apple TV 3gen",
         AppleTV4           = "Apple TV 4gen",
         AppleTV_4K         = "Apple TV 4K",
         AppleTV2_4K        = "Apple TV 4K 2gen",
         
         unrecognized       = "?unrecognized?"
}

// #-#-#-#-#-#-#-#-#-#-#-#-#
// MARK: UIDevice extensions
// #-#-#-#-#-#-#-#-#-#-#-#-#

public extension UIDevice {
    
    var type: Model {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        
        let modelMap : [String: Model] = [
            
            //Simulator
            "i386"      : .simulator,
            "x86_64"    : .simulator,
            
            //iPod
            "iPod1,1"   : .iPod1,
            "iPod2,1"   : .iPod2,
            "iPod3,1"   : .iPod3,
            "iPod4,1"   : .iPod4,
            "iPod5,1"   : .iPod5,
            "iPod7,1"   : .iPod6,
            "iPod9,1"   : .iPod7,
            
            //iPad
            "iPad2,1"   : .iPad2,
            "iPad2,2"   : .iPad2,
            "iPad2,3"   : .iPad2,
            "iPad2,4"   : .iPad2,
            "iPad3,1"   : .iPad3,
            "iPad3,2"   : .iPad3,
            "iPad3,3"   : .iPad3,
            "iPad3,4"   : .iPad4,
            "iPad3,5"   : .iPad4,
            "iPad3,6"   : .iPad4,
            "iPad6,11"  : .iPad5, //iPad 2017
            "iPad6,12"  : .iPad5,
            "iPad7,5"   : .iPad6, //iPad 2018
            "iPad7,6"   : .iPad6,
            "iPad7,11"  : .iPad7, //iPad 2019
            "iPad7,12"  : .iPad7,
            "iPad11,6"  : .iPad8, //iPad 2020
            "iPad11,7"  : .iPad8,
            "iPad12,1"  : .iPad9, //iPad 2021
            "iPad12,2"  : .iPad9,
            "iPad13,18" : .iPad10,
            "iPad13,19" : .iPad10,
            
            //iPad Mini
            "iPad2,5"   : .iPadMini,
            "iPad2,6"   : .iPadMini,
            "iPad2,7"   : .iPadMini,
            "iPad4,4"   : .iPadMini2,
            "iPad4,5"   : .iPadMini2,
            "iPad4,6"   : .iPadMini2,
            "iPad4,7"   : .iPadMini3,
            "iPad4,8"   : .iPadMini3,
            "iPad4,9"   : .iPadMini3,
            "iPad5,1"   : .iPadMini4,
            "iPad5,2"   : .iPadMini4,
            "iPad11,1"  : .iPadMini5,
            "iPad11,2"  : .iPadMini5,
            "iPad14,1"  : .iPadMini6,
            "iPad14,2"  : .iPadMini6,
            
            //iPad Pro
            "iPad6,3"   : .iPadPro9_7,
            "iPad6,4"   : .iPadPro9_7,
            "iPad7,3"   : .iPadPro10_5,
            "iPad7,4"   : .iPadPro10_5,
            "iPad6,7"   : .iPadPro12_9,
            "iPad6,8"   : .iPadPro12_9,
            "iPad7,1"   : .iPadPro2_12_9,
            "iPad7,2"   : .iPadPro2_12_9,
            "iPad8,1"   : .iPadPro11,
            "iPad8,2"   : .iPadPro11,
            "iPad8,3"   : .iPadPro11,
            "iPad8,4"   : .iPadPro11,
            "iPad8,9"   : .iPadPro2_11,
            "iPad8,10"  : .iPadPro2_11,
            "iPad13,4"  : .iPadPro3_11,
            "iPad13,5"  : .iPadPro3_11,
            "iPad13,6"  : .iPadPro3_11,
            "iPad13,7"  : .iPadPro3_11,
            "iPad8,5"   : .iPadPro3_12_9,
            "iPad8,6"   : .iPadPro3_12_9,
            "iPad8,7"   : .iPadPro3_12_9,
            "iPad8,8"   : .iPadPro3_12_9,
            "iPad8,11"  : .iPadPro4_12_9,
            "iPad8,12"  : .iPadPro4_12_9,
            "iPad13,8"  : .iPadPro5_12_9,
            "iPad13,9"  : .iPadPro5_12_9,
            "iPad13,10" : .iPadPro5_12_9,
            "iPad13,11" : .iPadPro5_12_9,
            
            //iPad Air
            "iPad4,1"   : .iPadAir,
            "iPad4,2"   : .iPadAir,
            "iPad4,3"   : .iPadAir,
            "iPad5,3"   : .iPadAir2,
            "iPad5,4"   : .iPadAir2,
            "iPad11,3"  : .iPadAir3,
            "iPad11,4"  : .iPadAir3,
            "iPad13,1"  : .iPadAir4,
            "iPad13,2"  : .iPadAir4,
            "iPad13,16" : .iPadAir5,
            "iPad13,17" : .iPadAir5,
            
            //iPhone
            "iPhone3,1" : .iPhone4,
            "iPhone3,2" : .iPhone4,
            "iPhone3,3" : .iPhone4,
            "iPhone4,1" : .iPhone4S,
            "iPhone5,1" : .iPhone5,
            "iPhone5,2" : .iPhone5,
            "iPhone5,3" : .iPhone5C,
            "iPhone5,4" : .iPhone5C,
            "iPhone6,1" : .iPhone5S,
            "iPhone6,2" : .iPhone5S,
            "iPhone7,1" : .iPhone6Plus,
            "iPhone7,2" : .iPhone6,
            "iPhone8,1" : .iPhone6S,
            "iPhone8,2" : .iPhone6SPlus,
            "iPhone8,4" : .iPhoneSE,
            "iPhone9,1" : .iPhone7,
            "iPhone9,3" : .iPhone7,
            "iPhone9,2" : .iPhone7Plus,
            "iPhone9,4" : .iPhone7Plus,
            "iPhone10,1" : .iPhone8,
            "iPhone10,4" : .iPhone8,
            "iPhone10,2" : .iPhone8Plus,
            "iPhone10,5" : .iPhone8Plus,
            "iPhone10,3" : .iPhoneX,
            "iPhone10,6" : .iPhoneX,
            "iPhone11,2" : .iPhoneXS,
            "iPhone11,4" : .iPhoneXSMax,
            "iPhone11,6" : .iPhoneXSMax,
            "iPhone11,8" : .iPhoneXR,
            "iPhone12,1" : .iPhone11,
            "iPhone12,3" : .iPhone11Pro,
            "iPhone12,5" : .iPhone11ProMax,
            "iPhone12,8" : .iPhoneSE2,
            "iPhone13,1" : .iPhone12Mini,
            "iPhone13,2" : .iPhone12,
            "iPhone13,3" : .iPhone12Pro,
            "iPhone13,4" : .iPhone12ProMax,
            "iPhone14,4" : .iPhone13Mini,
            "iPhone14,5" : .iPhone13,
            "iPhone14,2" : .iPhone13Pro,
            "iPhone14,3" : .iPhone13ProMax,
            "iPhone14,6" : .iPhoneSE3,
            "iPhone14,7" : .iPhone14,
            "iPhone14,8" : .iPhone14Plus,
            "iPhone15,2" : .iPhone14Pro,
            "iPhone15,3" : .iPhone14ProMax,
            "iPhone15,4" : .iPhone15,
            "iPhone15,5" : .iPhone15Plus,
            "iPhone16,1" : .iPhone15Pro,
            "iPhone16,2" : .iPhone15ProMax,
            
            // Apple Watch
            "Watch1,1" : .AppleWatch1,
            "Watch1,2" : .AppleWatch1,
            "Watch2,6" : .AppleWatchS1,
            "Watch2,7" : .AppleWatchS1,
            "Watch2,3" : .AppleWatchS2,
            "Watch2,4" : .AppleWatchS2,
            "Watch3,1" : .AppleWatchS3,
            "Watch3,2" : .AppleWatchS3,
            "Watch3,3" : .AppleWatchS3,
            "Watch3,4" : .AppleWatchS3,
            "Watch4,1" : .AppleWatchS4,
            "Watch4,2" : .AppleWatchS4,
            "Watch4,3" : .AppleWatchS4,
            "Watch4,4" : .AppleWatchS4,
            "Watch5,1" : .AppleWatchS5,
            "Watch5,2" : .AppleWatchS5,
            "Watch5,3" : .AppleWatchS5,
            "Watch5,4" : .AppleWatchS5,
            "Watch5,9" : .AppleWatchSE,
            "Watch5,10" : .AppleWatchSE,
            "Watch5,11" : .AppleWatchSE,
            "Watch5,12" : .AppleWatchSE,
            "Watch6,1" : .AppleWatchS6,
            "Watch6,2" : .AppleWatchS6,
            "Watch6,3" : .AppleWatchS6,
            "Watch6,4" : .AppleWatchS6,
            "Watch6,6" : .AppleWatchS7,
            "Watch6,7" : .AppleWatchS7,
            "Watch6,8" : .AppleWatchS7,
            "Watch6,9" : .AppleWatchS7,
            
            //Apple TV
            "AppleTV1,1" : .AppleTV1,
            "AppleTV2,1" : .AppleTV2,
            "AppleTV3,1" : .AppleTV3,
            "AppleTV3,2" : .AppleTV3,
            "AppleTV5,3" : .AppleTV4,
            "AppleTV6,2" : .AppleTV_4K,
            "AppleTV11,1" : .AppleTV2_4K
        ]
        
        guard let mcode = modelCode, let map = String(validatingUTF8: mcode), let model = modelMap[map] else { return Model.unrecognized }
        if model == .simulator {
            if let simModelCode = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
                if let simMap = String(validatingUTF8: simModelCode), let simModel = modelMap[simMap] {
                    return simModel
                }
            }
        }
        return model
    }
}



func GetUIImage(imageName: String, color: UIColor, hierarichal: Bool) -> UIImage {
    var image = UIImage(systemName: imageName)?.withTintColor(color)
    
    if (hierarichal) {
        let config = UIImage.SymbolConfiguration(hierarchicalColor: color)
        image = UIImage(systemName: imageName, withConfiguration: config)
    }
    
    return image!
}
