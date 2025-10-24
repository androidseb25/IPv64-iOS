//
//  RecordInfos.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//
import Foundation

// MARK: - RecordInfos

struct RecordInfos: Codable, Equatable, Identifiable {
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
}
