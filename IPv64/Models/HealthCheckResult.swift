//
//  HealthCheckResult.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 27.10.25.
//
import Foundation

struct HealthCheckResult: Codable {
    
    var domain: [HealthCheck] = []
    var info: String = ""
    var status: String = ""
    var get_account_info: String = ""
    
    static let empty: HealthCheckResult = HealthCheckResult(domain: [], info: "", status: "", get_account_info: "")
    
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
