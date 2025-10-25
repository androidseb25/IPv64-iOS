//
//  AddDomainResult.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 25.10.25.
//
import Foundation

struct AddDomainResult : Codable {
    var info: String?
    var status: String = ""
    var add_domain: String?
    
    enum CodingKeys: String, CodingKey {
        case info = "info"
        case status = "status"
        case add_domain = "add_domain"
    }
}
