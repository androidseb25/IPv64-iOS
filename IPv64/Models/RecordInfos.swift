//
//  RecordInfos.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//
import Foundation

// MARK: - RecordInfos

struct RecordInfos: Codable, Equatable, Identifiable, Hashable {
    var recordId: Int?
    var content: String?
    var ttl: Int?
    var type: String?
    var praefix: String?
    var lastUpdate: String?
    
    // zusätzliche Felder aus deinem Beispiel
    var recordKey: String?
    var deactivated: Int?
    var failoverPolicy: String?
    
    var id: Int { recordId ?? 0 }
    
    enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case content = "content"
        case ttl = "ttl"
        case type = "type"
        case praefix = "praefix"
        case lastUpdate = "last_update"
        case recordKey = "record_key"
        case deactivated = "deactivated"
        case failoverPolicy = "failover_policy"
    }
    
    static let empty = RecordInfos(
        recordId: 0, content: "", ttl: 0, type: "",
        praefix: "", lastUpdate: "", recordKey: "", deactivated: 0, failoverPolicy: "0"
    )
    
    var LastUpdate: String {
        guard let date = DateFormatter.db.date(from: lastUpdate ?? "0001-01-01 00:00:00")
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
