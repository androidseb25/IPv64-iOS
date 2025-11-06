//
//  ApiServiceWidget.swift
//  IPv64WidgetExtension
//
//  Created by Sebastian Rank on 04.11.25.
//

import Foundation
import Combine
import SwiftyBeaver

class ApiServiceWidget: ObservableObject {
    
    @Published public var isLoading: Bool = false
    
    let JsonEncoder = JSONEncoder()
    let JsonDecoder = JSONDecoder()
    
    let apiUrl = "https://ipv64.net/api.php"
    
    @MainActor
    func GetHealthchecks() async -> HealthCheckResult? {
        let urlString = "\(apiUrl)?get_healthchecks&events"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorageWidget.shared.ApiKey
            iLogger.log.info("Token: \(token)")
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(HealthCheckResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetHealthchecks", error)
            return nil
        }
    }
}
