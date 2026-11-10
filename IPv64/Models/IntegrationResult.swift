//
//  IntegrationResult.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//
import Foundation

// MARK: - IntegrationResult (mit dynamischem Decoding)

struct IntegrationResult: Codable, Equatable {
    var integrations: [Integration]
    var info: String
    var status: String
    var getAccountInfo: String
    
    static let empty = IntegrationResult(integrations: [], info: "", status: "", getAccountInfo: "")
    
    init(integrations: [Integration], info: String, status: String, getAccountInfo: String) {
        self.integrations = integrations
        self.info = info
        self.status = status
        self.getAccountInfo = getAccountInfo
    }
    
    // dynamische Keys
    struct AnyKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }
    
    enum MetaKeys: String {
        case info, status, get_account_info
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        
        var tmpIntegrations: [Integration] = []
        var info = ""
        var status = ""
        var getAccountInfo = ""
        
        for key in container.allKeys {
            switch key.stringValue {
            case MetaKeys.info.rawValue:
                info = try container.decodeIfPresent(String.self, forKey: key) ?? ""
            case MetaKeys.status.rawValue:
                status = try container.decodeIfPresent(String.self, forKey: key) ?? ""
            case MetaKeys.get_account_info.rawValue:
                getAccountInfo = try container.decodeIfPresent(String.self, forKey: key) ?? ""
            default:
                // Alles andere als Integration interpretieren
                if let integration = try container.decodeIfPresent(Integration.self, forKey: key) {
                    var i = integration
                    // dynamischen Key als Name sichern (optional)
                    if i.integrationName.isEmpty {
                        i.integrationName = key.stringValue
                    }
                    i.keyName = key.stringValue
                    // leere Options zu .empty
                    if i.options == nil { i.options = .empty }
                    tmpIntegrations.append(i)
                }
            }
        }
        
        self.integrations = tmpIntegrations
        self.info = info
        self.status = status
        self.getAccountInfo = getAccountInfo
    }
    
    // Optional: eigenes Encoding, wenn du das gleiche Schema zurückschreiben willst
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        try container.encode(info, forKey: AnyKey(stringValue: "info")!)
        try container.encode(status, forKey: AnyKey(stringValue: "status")!)
        try container.encode(getAccountInfo, forKey: AnyKey(stringValue: "get_account_info")!)
        for integration in integrations {
            let key = AnyKey(stringValue: integration.keyName ?? (integration.integrationName))!
            try container.encode(integration, forKey: key)
        }
    }
}
