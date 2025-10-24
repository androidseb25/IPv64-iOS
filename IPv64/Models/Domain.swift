//
//  Domain.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//
import Foundation
import SwiftUI

// MARK: - Domain

struct Domain: Codable, Equatable {
    var updates: Int?
    var wildcard: Int?
    var domainUpdateHash: String?
    var records: [RecordInfos]?
    
    // zusätzliche optionale Felder aus Beispiel
    var ipv6prefix: String?
    var dualstack: String?
    var deactivated: Int?
    
    // kommt NICHT aus JSON – setzen wir aus dem Subdomain-Key
    var fqdn: String = ""
    
    // Defaults wie im Kotlin-Modell
    var ipv4: String = "0.0.0.0"
    var ipv6: String = "::1"
    
    enum CodingKeys: String, CodingKey {
        case updates = "updates"
        case wildcard = "wildcard"
        case domainUpdateHash = "domain_update_hash"
        case records = "records"
        case ipv6prefix = "ipv6prefix"
        case dualstack = "dualstack"
        case deactivated = "deactivated"
        // fqdn, ipv4, ipv6 absichtlich nicht gemappt (fqdn setzen wir manuell)
    }
    
    // Kotlin-Computed: "no"/"yes"
    var isWildcardString: String {
        (wildcard ?? 0) == 0 ? "no" : "yes"
    }
    
    var isSameTypeAAddress: Bool {
        guard let records else { return false }
        return records.contains { $0.type == "A" && $0.content == ipv4 }
    }
    
    var isSameTypeAAAAAddress: Bool {
        guard let records else { return false }
        return records.contains { $0.type == "AAAA" && $0.content == ipv6 }
    }
    
    // SwiftUI-Farbe (optional nutzbar)
    var tintColor: Color {
        (isSameTypeAAddress || isSameTypeAAAAAddress) ? .green : .red
    }
    
    /// Basierend auf dem FQDN die letzten zwei Labels.
    var baseDomain: String {
        if (fqdn.isEmpty) {
            return "Own Domain"
        }
        let parts = fqdn.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return "Own Domain" }
        let lastTwo = parts.suffix(2).joined(separator: ".")
        return "".v64domains().contains(lastTwo) ? lastTwo : "Own Domain"
    }
    
    static let empty = Domain(
        updates: 0, wildcard: 0, domainUpdateHash: "",
        records: [], ipv6prefix: "", dualstack: "", deactivated: 0,
        fqdn: "", ipv4: "0.0.0.0", ipv6: "::1"
    )
}
