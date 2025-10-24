//
//  Integration.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//
import Foundation
import SwiftUI

// MARK: - Integration

struct Integration: Codable, Identifiable, Equatable {
    var integration: String = ""         // z.B. "ntfy", "discord", ...
    var integrationId: Int?
    var integrationName: String = ""
    var options: IntegrationOptions?
    var addTime: String = ""
    var lastUsed: String = ""
    
    // Zusatzfelder (nicht aus JSON, aber praktisch)
    var selectedState: Bool = false
    var keyName: String? = nil        // Der dynamische JSON-Key ("Discord", "Ntfy", ...)
    
    var id: Int { integrationId ?? Int(bitPattern: ObjectIdentifier(self as AnyObject)) }
    
    enum CodingKeys: String, CodingKey {
        case integration = "integration"
        case integrationId = "integration_id"
        case integrationName = "integration_name"
        case options = "options"
        case addTime = "add_time"
        case lastUsed = "last_used"
    }
    
    /// SF Symbols Empfehlung (falls du Asset-Namen nutzt, ersetze einfach die Rückgabewerte).
    var icon: Image {
        switch integration.lowercased() {
        case "webhook":
            return Image("webhook")
        case "discord":
            return Image("discord")
        case "ntfy":
            return Image("ntfy")
        case "pushover":
            return Image("pushover")
        case "telegram":
            return Image("telegram")
        case "gotify":
            return Image("gotify")
        case "email":
            return Image(systemName: "envelope")
        case "sms":
            return Image(systemName: "message")
        case "mobil":
            return Image(systemName: "iphone")
        default:
            return Image(systemName: "app.dashed")
        }
    }
    
    var LastUsed: String {
        guard let date = DateFormatter.db.date(from: lastUsed)
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
    
    var AddTime: String {
        guard let date = DateFormatter.db.date(from: addTime)
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
