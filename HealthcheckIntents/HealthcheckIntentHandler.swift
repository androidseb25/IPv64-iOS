//
//  HealthcheckIntentHandler.swift
//  HealthcheckIntents
//
//  Created by Sebastian Rank on 20.01.23.
//

import Foundation
import Intents

class HealthcheckIntentHandler: NSObject, HealthcheckIntentHandling {
    
    func resolveDomain(for intent: HealthcheckIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        completion(.success(with: "DD"))
    }
    
    func resolveStatus(for intent: HealthcheckIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        completion(.success(with: "DD"))
    }
    
    
    func handle(intent: HealthcheckIntent, completion: @escaping (HealthcheckIntentResponse) -> Void) {
        completion(.success(status: "Failed")) // TODO Load correct data.
    }
    
}
