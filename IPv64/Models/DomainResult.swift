//
//  DomainResult.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//
import Foundation

// MARK: - DomainResult (dynamisches Decoding der "subdomains")

struct DomainResult: Codable, Equatable {
    var subdomains: [Domain]
    var info: String
    var status: String
    var addDomain: String
    
    static let empty = DomainResult(subdomains: [], info: "", status: "", addDomain: "")
    
    // eigener Memberwise-Init (weil wir custom init(from:) definieren)
    init(subdomains: [Domain], info: String, status: String, addDomain: String) {
        self.subdomains = subdomains
        self.info = info
        self.status = status
        self.addDomain = addDomain
    }
    
    private struct RootCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
        
        static let subdomains = RootCodingKeys(stringValue: "subdomains")!
        static let info       = RootCodingKeys(stringValue: "info")!
        static let status     = RootCodingKeys(stringValue: "status")!
        static let addDomain  = RootCodingKeys(stringValue: "add_domain")!
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Meta
        self.info      = try c.decodeIfPresent(String.self, forKey: .info) ?? ""
        self.status    = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.addDomain = try c.decodeIfPresent(String.self, forKey: .addDomain) ?? ""
        
        // subdomains kann ein Objekt (Map) oder ein Array sein
        if c.contains(.subdomains) {
            // Versuche zuerst als Objekt (Map: fqdn -> Domain)
            if let nested = try? c.nestedContainer(keyedBy: DynamicKey.self, forKey: .subdomains) {
                var domains: [Domain] = []
                for key in nested.allKeys {
                    if let d = try nested.decodeIfPresent(Domain.self, forKey: key) {
                        var domain = d
                        domain.fqdn = key.stringValue   // FQDN aus Key setzen
                        domains.append(domain)
                    }
                }
                self.subdomains = domains
            }
            // Fallback: Array
            else if var nestedArray = try? c.nestedUnkeyedContainer(forKey: .subdomains) {
                var arr: [Domain] = []
                while !nestedArray.isAtEnd {
                    let d = try nestedArray.decode(Domain.self)
                    arr.append(d)
                }
                self.subdomains = arr
            } else {
                self.subdomains = []
            }
        } else {
            self.subdomains = []
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: RootCodingKeys.self)
        try c.encode(info, forKey: .info)
        try c.encode(status, forKey: .status)
        try c.encode(addDomain, forKey: .addDomain)
        
        // Als Map zurückschreiben (fqdn -> Domain), falls fqdn vorhanden; sonst als Array.
        var map = [String: Domain]()
        var arrayFallback: [Domain] = []
        for d in subdomains {
            if (d.fqdn.isEmpty) {
                arrayFallback.append(d)
            } else {
                map[d.fqdn] = d
            }
        }
        
        if !map.isEmpty {
            var nested = c.nestedContainer(keyedBy: DynamicKey.self, forKey: .subdomains)
            for (k, v) in map {
                try nested.encode(v, forKey: DynamicKey(stringValue: k)!)
            }
        } else {
            try c.encode(arrayFallback, forKey: .subdomains)
        }
    }
}

// Hilfs-CodingKey für dynamische Dictionary-Keys
private struct DynamicKey: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { return nil }
}
