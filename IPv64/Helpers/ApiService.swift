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
            print("Failed to GetAccountStatus", error)
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
    
    @MainActor func PostDomain(domain: String) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorage.shared.ApiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "POST"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "add_domain=\(domain)".data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to PostDomain", error)
            return nil
        }
    }
    
    @MainActor func DeleteDNSRecord(recordId: Int) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorage.shared.ApiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "DELETE"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "del_record=\(recordId)".data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to DeleteDNSRecord", error)
            return nil
        }
    }
    
    @MainActor
    func UpdateDNSRecord(urlDNSUpdate: String) async -> IPUpdateResult? {
        isLoading = true
        
        guard let url = URL(string: urlDNSUpdate) else {
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
            
            let result = try JsonDecoder.decode(IPUpdateResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to UpdateDNSRecord", error)
            return nil
        }
    }
    
    @MainActor func DeleteDomain(domain: String) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorage.shared.ApiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "DELETE"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type");
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "del_domain=\(domain)".data(using: .utf8)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            // Default fallback
            var result = AddDomainResult(info: "unknown error", status: "\(httpResponse.statusCode)", add_domain: "unknown error")
            
            switch httpResponse.statusCode {
            case 200..<300:
                // OK – decode your normal success response
                result = try JSONDecoder().decode(AddDomainResult.self, from: data)
            case 400:
                result = AddDomainResult(info: "Bad Request", status: "400", add_domain: "Client Error")
            case 401:
                result = AddDomainResult(info: "Unauthorized", status: "401", add_domain: "Client Error")
            case 403:
                result = AddDomainResult(info: "Forbidden", status: "403", add_domain: "Client Error")
            case 404:
                result = AddDomainResult(info: "Not Found", status: "404", add_domain: "Client Error")
            case 408:
                result = AddDomainResult(info: "Request Timeout", status: "408", add_domain: "Client Error")
            case 409:
                result = AddDomainResult(info: "Conflict", status: "409", add_domain: "Client Error")
            case 410:
                result = AddDomainResult(info: "Gone", status: "410", add_domain: "Client Error")
            case 418:
                result = AddDomainResult(info: "I'm a teapot ☕️", status: "418", add_domain: "Client Error")
            case 429:
                result = AddDomainResult(info: "Too Many Requests", status: "429", add_domain: "Client Error")
            case 500:
                result = AddDomainResult(info: "Internal Server Error", status: "500", add_domain: "Server Error")
            case 501:
                result = AddDomainResult(info: "Not Implemented", status: "501", add_domain: "Server Error")
            case 502:
                result = AddDomainResult(info: "Bad Gateway", status: "502", add_domain: "Server Error")
            case 503:
                result = AddDomainResult(info: "Service Unavailable", status: "503", add_domain: "Server Error")
            case 504:
                result = AddDomainResult(info: "Gateway Timeout", status: "504", add_domain: "Server Error")
            default:
                result = AddDomainResult(info: "Unexpected HTTP Error", status: "\(httpResponse.statusCode)", add_domain: "Unknown Error")
            }
            
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to DeleteDomain", error)
            return nil
        }
    }
    
    @MainActor func PostDNSRecord(domain: String, praefix: String, typ: String, content: String) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorage.shared.ApiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "POST"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "add_record=\(domain)&praefix=\(praefix)&type=\(typ)&content=\(content)".data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to PostDNSRecord", error)
            return nil
        }
    }
    
    @MainActor
    func GetHealthchecks() async -> HealthCheckResult? {
        let urlString = "\(apiUrl)?get_healthchecks&events"
        
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
            
            let result = try JsonDecoder.decode(HealthCheckResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetHealthchecks", error)
            return nil
        }
    }
    
    @MainActor func PostStartPauseHealthcheck(startPause: String, hcToken: String) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorage.shared.ApiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "POST"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "\(startPause)=\(hcToken)".data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to PostStartPauseHealthcheck", error)
            return nil
        }
    }
    
    @MainActor func PostHealthcheck(add_healthcheck: String, alarm_count: Int, alarm_unit: Int) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorage.shared.ApiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "POST"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "add_healthcheck=\(add_healthcheck)&alarm_count=\(alarm_count)&alarm_unit=\(alarm_unit)".data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to PostHealthcheck", error)
            return nil
        }
    }
    
    @MainActor func DeleteHealthcheck(hcToken: String) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = UserStorage.shared.ApiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "DELETE"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type");
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "del_healthcheck=\(hcToken)".data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to DeleteHealthcheck", error)
            return nil
        }
    }
    
    @MainActor func PostEditHealthcheck(healthcheck: HealthCheck) async -> AddDomainResult? {
            let urlString = "\(apiUrl)"
            
            isLoading = true
            
            guard let url = URL(string: urlString) else {
                isLoading = false
                return nil
            }
            
            do {
                let token = UserStorage.shared.ApiKey
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
                request.httpMethod = "POST"
                //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
                request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
                request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
                JsonEncoder.outputFormatting = .prettyPrinted
                
                let body = "edit_healthcheck=\(healthcheck.healthtoken)&healthcheck_name=\(healthcheck.name)&alarm_count=\(healthcheck.alarm_count)&alarm_unit=\(healthcheck.alarm_unit)&integration=\(healthcheck.integration_id)&grace_count=\(healthcheck.grace_count)&grace_unit=\(healthcheck.grace_unit)&alarm_down=\(healthcheck.alarm_down)&alarm_up=\(healthcheck.alarm_up)"
                
                request.httpBody = body.data(using: .utf8)
                
                let (data, _) = try await URLSession.shared.data(for: request)
                
                let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
                isLoading = false
                return result
            } catch let error {
                isLoading = false
                print("Failed to PostEditHealthcheck", error)
                return nil
            }
        }
}
