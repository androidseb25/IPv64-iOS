//
//  ApiService.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 20.10.25.
//


import Foundation
import Combine

class ApiService: ObservableObject {
    
    @Published public var isLoading: Bool = false
    
    let JsonEncoder = JSONEncoder()
    let JsonDecoder = JSONDecoder()
    
    let apiUrl = "https://ipv64.net/api.php"
    
    @MainActor
    func GetAccountStatus() async -> AccountInfo? {
        let urlString = "\(apiUrl)?get_account_info"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorage.shared.ApiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AccountInfo.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to Get Account Status", error)
            return nil
        }
    }
    
    @MainActor
    func GetLogs() async -> Logs? {
        let urlString = "\(apiUrl)?get_logs"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorage.shared.ApiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(Logs.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetLogs", error)
            return nil
        }
    }
    
    @MainActor
    func GetMyIp(_ onlyV4: Bool = true) async -> MyIP? {
        let urlString = onlyV4 ? "https://ipv4.ipv64.net/update.php?howismyip" : "https://ipv6.ipv64.net/update.php?howismyip"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(MyIP.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetMyIp \(onlyV4 ? "v4" : "v6")", error)
            return nil
        }
    }
    
    @MainActor
    func GetIntegrations() async -> IntegrationResult? {
        let urlString = "\(apiUrl)?get_integrations"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorage.shared.ApiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try IntegrationResult.parse(jsonData: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetIntegrations", error)
            return nil
        }
    }
    
    @MainActor
    func GetDomains() async -> DomainResult? {
        let urlString = "\(apiUrl)?get_domains"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorage.shared.ApiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try DomainResult.parse(jsonData: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetDomains", error)
            return nil
        }
    }
}
