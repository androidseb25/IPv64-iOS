//
//  Logs.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//

import Foundation

struct Logs: Codable {
    var logs: [MyLogs] = []
    
    enum CodingKeys: String, CodingKey {
        case logs = "logs"
    }
    
    static let empty = Logs(logs: [])
}

struct MyLogs: Codable, Identifiable {
    var id: String = UUID().uuidString
    var subdomain: String = ""
    var time: String = ""
    var header: String = ""
    var content: String = ""
    
    enum CodingKeys: String, CodingKey {
        case subdomain = "subdomain"
        case time = "time"
        case header = "header"
        case content = "content"
    }
    
    var LogTime: String {
        guard let date = DateFormatter.db.date(from: time)
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
