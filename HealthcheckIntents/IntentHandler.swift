//
//  IntentHandler.swift
//  HealthcheckIntents
//
//  Created by Sebastian Rank on 27.01.23.
//

import Intents
import SwiftUI

class IntentHandler: INExtension, ConfigurationIntentHandling {
    
    func resolveHealthcheckSymbol1(for intent: ConfigurationIntent) async -> HealthcheckSymbolResolutionResult {
        return .success(with: HealthcheckSymbol(identifier: "", display: ""))
    }
    
    
    func provideHealthcheckSymbol1OptionsCollection(for intent: ConfigurationIntent) async throws -> INObjectCollection<HealthcheckSymbol> {
        var symbols:[HealthcheckSymbol] = []
        
        let api = NetworkServices()
        let hcd = DummyData.HealthcheckListCustom(customCount: 2)
        let hcr = await api.GetHealthchecks() ?? HealthCheckResult(domain: hcd)
        
        let shrinkedEventList = hcr.domain.sorted { $0.name > $1.name }
        shrinkedEventList.forEach { health in
            var healthStatus = HealthcheckSymbol(identifier: health.healthtoken, display: health.name)
            healthStatus.events = []
            print(health.events)
            health.events.forEach { e in
                let event = EventSymbol(identifier: UUID().uuidString, display: e.status!.formatted())
                healthStatus.events?.append(event)
            }
            
            symbols.append(healthStatus)
        }
        // Create a collection with the array of characters.
        let collection = INObjectCollection(items: symbols)
        print("Collection")
        print(collection)
        // Call the completion handler, passing the collection.
        return collection
    }
    
    func resolveHealthcheckSymbol2(for intent: ConfigurationIntent) async -> HealthcheckSymbolResolutionResult {
        return .success(with: HealthcheckSymbol(identifier: "", display: ""))
    }
    
    
    func provideHealthcheckSymbol2OptionsCollection(for intent: ConfigurationIntent) async throws -> INObjectCollection<HealthcheckSymbol> {
        var symbols:[HealthcheckSymbol] = []
        
        let api = NetworkServices()
        let hcd = DummyData.HealthcheckListCustom(customCount: 2)
        let hcr = await api.GetHealthchecks() ?? HealthCheckResult(domain: hcd)
        
        let shrinkedEventList = hcr.domain.sorted { $0.name > $1.name }
        shrinkedEventList.forEach { health in
            var healthStatus = HealthcheckSymbol(identifier: health.healthtoken, display: health.name)
            healthStatus.events = []
            print(health.events)
            health.events.forEach { e in
                let event = EventSymbol(identifier: UUID().uuidString, display: e.status!.formatted())
                healthStatus.events?.append(event)
            }
            
            symbols.append(healthStatus)
        }
        // Create a collection with the array of characters.
        let collection = INObjectCollection(items: symbols)
        print("Collection")
        print(collection)
        // Call the completion handler, passing the collection.
        return collection
    }
    
}
