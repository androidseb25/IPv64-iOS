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
    var sms_count: Int? = 0
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
        case sms_count = "sms_count"
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
            print(key)
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
    var integration_id: Int = 0
    var alarm_count: Int = 0
    var alarm_unit: Int = 0
    var grace_count: Int = 0
    var grace_unit: Int = 0
    var pings_total: Int = 0
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
        integration_id = try container.decode(Int.self, forKey: CodingKeys.integration_id)
        alarm_count = try container.decode(Int.self, forKey: CodingKeys.alarm_count)
        alarm_unit = try container.decode(Int.self, forKey: CodingKeys.alarm_unit)
        grace_count = try container.decode(Int.self, forKey: CodingKeys.grace_count)
        grace_unit = try container.decode(Int.self, forKey: CodingKeys.grace_unit)
        pings_total = try container.decode(Int.self, forKey: CodingKeys.pings_total)
        events = try container.decode([HealthEvents].self, forKey: CodingKeys.events)
        
        // 4
        // Extract healthcheckDomain from coding path
        if (container.codingPath.first!.stringValue != nil) {
            keyInd = container.codingPath.first!.stringValue
        }
    }
    
    init(name: String = "", healthstatus: Int = 0, healthtoken: String = "", add_time: String? = "", last_update_time: String? = "", alarm_time: String? = "", alarm_down: Int = 0, alarm_up: Int = 0, integration_id: Int = 0, alarm_count: Int = 0, alarm_unit: Int = 0, grace_count: Int = 0, grace_unit: Int = 0, pings_total: Int = 0, events: [HealthEvents] = []) {
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
            print(key)
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

struct Integration: Codable {
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
        print(decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
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
    case detail, add, adddns, help, error, qrcode, whatsnew, edit
    
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
        integration_id: 0,
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
