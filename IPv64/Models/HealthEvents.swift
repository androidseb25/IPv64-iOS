//
//  HealthEvents.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 27.10.25.
//
import Foundation

struct HealthEvents: Codable, Equatable, Hashable {
    var event_time: String?
    var status: Int?
    var text: String?
    var uuid: UUID = UUID()
    
    enum CodingKeys: String, CodingKey {
        case event_time = "event_time"
        case status = "status"
        case text = "text"
    }
    
    var HealthStatus: Status {
        switch status {
        case 1: return .active
        case 2: return .pause
        case 3: return .warning
        case 4: return .alarm
        default: return .unknown
        }
    }
    
    var EventTime: String {
        guard let date = DateFormatter.db.date(from: event_time ?? "0001-01-01 00:00:00")
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
}
