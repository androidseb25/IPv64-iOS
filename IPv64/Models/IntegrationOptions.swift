//
//  IntegrationOptions.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//

import Foundation

// MARK: - IntegrationOptions

struct IntegrationOptions: Codable, Equatable {
    var serverurl: String?
    var downprio: String?
    var upprio: String?
    var number: String?
    var countrycode: String?
    var completenumber: String?
    var key: String?
    var webhookurl: String?
    var pinguser: String?
    var pinggroup: String?
    var email: String?
    var devicetoken: String?
    var apptoken: String?
    var priority: String?
    
    static let empty = IntegrationOptions(
        serverurl: nil, downprio: nil, upprio: nil, number: nil,
        countrycode: nil, completenumber: nil, key: nil, webhookurl: nil,
        pinguser: nil, pinggroup: nil, email: nil, devicetoken: nil,
        apptoken: nil, priority: nil
    )
}
