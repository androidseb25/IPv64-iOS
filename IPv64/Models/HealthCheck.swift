//
//  HealthCheck.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 27.10.25.
//
import Foundation

struct HealthCheck: Codable, Equatable, Hashable {
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
    var type_options: String = ""
    var next_ping: String = ""
    var events: [HealthEvents] = []
    
    static let empty = HealthCheck(name: "", healthstatus: 0, healthtoken: "")
    
    var GraceUnit: Unit {
        switch grace_unit {
        case 1: return .minute
        case 2: return .hour
        case 3: return .day
        default: return .unknown
        }
    }
    
    var AlarmUnit: Unit {
        switch alarm_unit {
        case 1: return .minute
        case 2: return .hour
        case 3: return .day
        default: return .unknown
        }
    }
    
    var IsAlarmUp: Bool {
        alarm_up == 1
    }
    
    var IsAlarmDown: Bool {
        alarm_down == 1
    }
    
    var AlarmUp: String {
        IsAlarmUp ? "yes" : "no"
    }
    
    var AlarmDown: String {
        IsAlarmDown ? "yes" : "no"
    }
    
    var HealthStatus: Status {
        switch healthstatus {
        case 1: return .active
        case 2: return .pause
        case 3: return .warning
        case 4: return .alarm
        default: return .unknown
        }
    }
    
    var AddTime: String {
        guard let date = DateFormatter.db.date(from: add_time ?? "0001-01-01 00:00:00")
        else { return "01.01.0001 00:00:00" }
        
        return date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .day(.twoDigits)
                .month(.twoDigits)
                .year(.defaultDigits)
                .locale(Locale(identifier: "de_DE"))
        )
    }
    
    var LastUpdateTime: String {
        guard let date = DateFormatter.db.date(from: last_update_time ?? "0001-01-01 00:00:00")
        else { return "01.01.0001 00:00:00" }
        
        return date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .day(.twoDigits)
                .month(.twoDigits)
                .year(.defaultDigits)
                .locale(Locale(identifier: "de_DE"))
        )
    }
    
    var NextAlarmTime: String {
        guard let date = DateFormatter.db.date(from: alarm_time ?? "0001-01-01 00:00:00")
        else { return "01.01.0001 00:00:00" }
        
        return date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .day(.twoDigits)
                .month(.twoDigits)
                .year(.defaultDigits)
                .locale(Locale(identifier: "de_DE"))
        )
    }
    
    var NextPing: String {
        guard let date = DateFormatter.db.date(from: next_ping)
        else { return "01.01.0001 00:00:00" }
        
        return date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .day(.twoDigits)
                .month(.twoDigits)
                .year(.defaultDigits)
                .locale(Locale(identifier: "de_DE"))
        )
    }
    
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
