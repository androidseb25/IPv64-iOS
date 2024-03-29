//
//  NetworkServices.swift
//  IPv64
//
//  Created by Sebastian Rank on 06.11.22.
//


import Foundation
import UIKit

class NetworkServices: ObservableObject {
    
    @Published var isLoading = false
    let JsonEncoder = JSONEncoder()
    let JsonDecoder = JSONDecoder()
    
    let apiUrl = "https://ipv64.net/api.php"
    
    init() { }
    
    @MainActor
    func GetDomains() async -> DomainResult? {
        let urlString = "\(apiUrl)?get_domains"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(DomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetDomains", error)
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
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
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
    func GetAccountStatus(apiKey: String = "") async -> AccountInfo? {
        let urlString = "\(apiUrl)?get_account_info"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = apiKey.count == 0 ? SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String : apiKey
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
            print("Failed to GetLogs", error)
            return nil
        }
    }
    
    @MainActor
    func GetMyIP() async -> MyIP? {
        let urlString = "https://ipv4.ipv64.net/update.php?howismyip"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let _ = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(MyIP.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetMyIP", error)
            return nil
        }
    }
    
    @MainActor
    func GetMyIPV6() async -> MyIP? {
        let urlString = "https://ipv6.ipv64.net/update.php?howismyip"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let _ = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(MyIP.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetMyIP", error)
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
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
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
            print("Failed to Post Domain", error)
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
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "DELETE"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type");
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "del_domain=\(domain)".data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to Post Domain", error)
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
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
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
            print("Failed to Post Domain", error)
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
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
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
            print("Failed to Post Domain", error)
            return nil
        }
    }
    
    @MainActor
    func UpdateDomainIp(updateKey: String, domain: String) async -> AddDomainResult? {
        
        let urlString = "https://ipv4.ipv64.net/update.php?key=\(updateKey)&domain=\(domain)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to Post Domain", error)
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
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
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
    
    @MainActor func PostHealth(add_healthcheck: String, alarm_count: Int, alarm_unit: Int) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
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
            print("Failed to PostHealth", error)
            return nil
        }
    }
    
    
    @MainActor func PostPauseHealth(healthtoken: String) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "POST"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "pause_healthcheck=\(healthtoken)".data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to PostPauseHealth", error)
            return nil
        }
    }
    
    
    @MainActor func PostStartHealth(healthtoken: String) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "POST"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "start_healthcheck=\(healthtoken)".data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to PostPauseHealth", error)
            return nil
        }
    }
    
    
    @MainActor func DeleteHealth(health: String) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "DELETE"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type");
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "del_healthcheck=\(health)".data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to Post Domain", error)
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
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(IntegrationResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetIntegrations", error)
            return nil
        }
    }
    
    
    @MainActor func PostEditHealthcheck(healthcheck: HealthCheck, integrationId: String) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "POST"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let body = "edit_healthcheck=\(healthcheck.healthtoken)&healthcheck_name=\(healthcheck.name)&alarm_count=\(healthcheck.alarm_count)&alarm_unit=\(healthcheck.alarm_unit)&integration=\(integrationId)&grace_count=\(healthcheck.grace_count)&grace_unit=\(healthcheck.grace_unit)&alarm_down=\(healthcheck.alarm_down)&alarm_up=\(healthcheck.alarm_up)"
            
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
    
    
    @MainActor func PostAddIntegration(integrationType: String, dtoken: String, dName: String, apiKey: String = "") async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = apiKey.count == 0 ? SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String : apiKey
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "POST"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let body = "add_integration=\(integrationType)&integration_name=\(dName)&devicetoken=\(dtoken)"
            
            request.httpBody = body.data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to PostDeviceToken", error)
            return nil
        }
    }
    
    
    
    @MainActor
    func GetHealthcheckStatistics(healthtoken: String) async -> HealthcheckStatisticsResult? {
        let urlString = "\(apiUrl)?get_healthcheck_statistics&healthtoken=\(healthtoken)"
        
        isLoading = false
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(HealthcheckStatisticsResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetHealthcheckStatistics", error)
            return nil
        }
    }
    
    @MainActor func DeleteIntegration(integration_id: Int) async -> AddDomainResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "DELETE"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type");
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            request.httpBody = "del_integration=\(integration_id)".data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(AddDomainResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to Post Domain", error)
            return nil
        }
    }
    
    @MainActor
    func GetBlockerNodes() async -> BlockerNodeResults? {
        let urlString = "\(apiUrl)?get_blockers"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "GET"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(BlockerNodeResults.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to GetBlockerNodes", error)
            return nil
        }
    }
    
    
    @MainActor func PostPoisonedIP(poisonedIp: PoisonedIP) async -> PoisonedIPResult? {
        let urlString = "\(apiUrl)"
        
        isLoading = true
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return nil
        }
        
        do {
            let token = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = "POST"
            //request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")  // the request is JSON
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")        // the expected response is also JSON
            request.setValue("Authorization: Bearer \(token)", forHTTPHeaderField: "Authorization")
            JsonEncoder.outputFormatting = .prettyPrinted
            
            let body = "blocker_id=\(poisonedIp.blocker_id)&report_ip=\(poisonedIp.report_ip)&port=\(poisonedIp.port!)&category=\(poisonedIp.category!)&info=\(poisonedIp.info!)"
            
            request.httpBody = body.data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let result = try JsonDecoder.decode(PoisonedIPResult.self, from: data)
            isLoading = false
            return result
        } catch let error {
            isLoading = false
            print("Failed to PostPoisonedIP", error)
            return nil
        }
    }
}
